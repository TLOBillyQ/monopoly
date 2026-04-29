package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type worktreeRequest struct {
	ProjectRoot string                  `json:"project_root"`
	Directories []worktreeDirectoryItem `json:"directories"`
	Files       []worktreeFileItem      `json:"files"`
}

type worktreeDirectoryItem struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

type worktreeFileItem struct {
	Name              string `json:"name"`
	Path              string `json:"path"`
	ExtraLinesIfExist int    `json:"extra_lines_if_exists"`
}

type breakdownItem struct {
	Name                  string `json:"name"`
	Kind                  string `json:"kind"`
	EffectiveLuaLineCount int    `json:"effective_lua_line_count"`
}

type worktreeResponse struct {
	Breakdown               []breakdownItem `json:"breakdown"`
	TotalEffectiveLineCount int             `json:"total_effective_line_count"`
}

type historyRequest struct {
	GitRoot string `json:"git_root"`
	Since   string `json:"since"`
}

type historyResponse struct {
	Rows []historyRow `json:"rows"`
}

type historyRow struct {
	Hash       string `json:"hash"`
	Date       string `json:"date"`
	Message    string `json:"message"`
	SrcLoc     int    `json:"src_loc"`
	SrcFiles   int    `json:"src_files"`
	TestsLoc   int    `json:"tests_loc"`
	TestsFiles int    `json:"tests_files"`
	TotalLoc   int    `json:"total_loc"`
	TotalFiles int    `json:"total_files"`
}

type commitInfo struct {
	Hash     string
	FullHash string
	Date     string
	Message  string
}

type treeEntry struct {
	Bucket   string
	ObjectID string
	FilePath string
}

type diffEntry struct {
	OldObjectID string
	NewObjectID string
	OldPath     string
	NewPath     string
}

type blobStats struct {
	LineCount  int
	HasContent bool
}

type stateEntry struct {
	Bucket   string
	ObjectID string
}

type historyState struct {
	PathToEntry map[string]stateEntry
	SrcLoc      int
	SrcFiles    int
	TestsLoc    int
	TestsFiles  int
}

func main() {
	if len(os.Args) < 4 || os.Args[2] != "--request-json" {
		fail("usage: monopoly-loc <worktree|history> --request-json <path>")
	}

	commandName := os.Args[1]
	requestPath := os.Args[3]

	switch commandName {
	case "worktree":
		runWorktree(requestPath)
	case "history":
		runHistory(requestPath)
	default:
		fail("unknown command: " + commandName)
	}
}

func runWorktree(requestPath string) {
	var request worktreeRequest
	mustLoadJSON(requestPath, &request)
	response, err := countWorktree(request)
	if err != nil {
		fail(err.Error())
	}
	mustWriteJSON(response)
}

func runHistory(requestPath string) {
	var request historyRequest
	mustLoadJSON(requestPath, &request)
	response, err := countHistory(request)
	if err != nil {
		fail(err.Error())
	}
	mustWriteJSON(response)
}

func countWorktree(request worktreeRequest) (worktreeResponse, error) {
	projectRoot := request.ProjectRoot
	if strings.TrimSpace(projectRoot) == "" {
		projectRoot = "."
	}

	response := worktreeResponse{
		Breakdown: make([]breakdownItem, 0, len(request.Directories)+len(request.Files)),
	}

	for _, directory := range request.Directories {
		total, err := countDirectory(projectRoot, directory.Path)
		if err != nil {
			return worktreeResponse{}, err
		}
		response.Breakdown = append(response.Breakdown, breakdownItem{
			Name:                  directory.Name,
			Kind:                  "Directory",
			EffectiveLuaLineCount: total,
		})
		response.TotalEffectiveLineCount += total
	}

	for _, fileItem := range request.Files {
		total, err := countFileItem(projectRoot, fileItem)
		if err != nil {
			return worktreeResponse{}, err
		}
		response.Breakdown = append(response.Breakdown, breakdownItem{
			Name:                  fileItem.Name,
			Kind:                  "File",
			EffectiveLuaLineCount: total,
		})
		response.TotalEffectiveLineCount += total
	}

	return response, nil
}

func countHistory(request historyRequest) (historyResponse, error) {
	gitRoot := strings.TrimSpace(request.GitRoot)
	if gitRoot == "" {
		gitRoot = "."
	}

	since := strings.TrimSpace(request.Since)
	if since == "" {
		since = "3 days ago"
	}

	commits, err := getCommits(gitRoot, since)
	if err != nil {
		return historyResponse{}, err
	}
	if len(commits) == 0 {
		return historyResponse{Rows: []historyRow{}}, nil
	}

	cache := map[string]blobStats{}
	baselineEntries, err := listCommitEntries(gitRoot, commits[0].FullHash)
	if err != nil {
		return historyResponse{}, err
	}
	state, err := buildStateFromEntries(gitRoot, commits[0].FullHash, baselineEntries, cache)
	if err != nil {
		return historyResponse{}, err
	}

	rows := make([]historyRow, 0, len(commits))
	rows = append(rows, makeHistoryRow(commits[0], state))

	for index := 1; index < len(commits); index++ {
		currentCommit := commits[index]
		previousCommit := commits[index-1]

		diffEntries, diffErr := listDiffEntries(gitRoot, previousCommit.FullHash, currentCommit.FullHash)
		if diffErr != nil {
			state, err = rebuildState(gitRoot, currentCommit.FullHash, cache)
		} else {
			err = applyDiffEntries(state, diffEntries, cache, gitRoot)
			if err != nil {
				state, err = rebuildState(gitRoot, currentCommit.FullHash, cache)
			}
		}
		if err != nil {
			return historyResponse{}, err
		}

		rows = append(rows, makeHistoryRow(currentCommit, state))
	}

	return historyResponse{Rows: rows}, nil
}

func countDirectory(projectRoot, relativePath string) (int, error) {
	files, err := collectDirectoryLuaFiles(projectRoot, relativePath)
	if err != nil {
		return 0, err
	}

	total := 0
	for _, path := range files {
		content, readErr := os.ReadFile(path)
		if readErr != nil {
			return 0, fmt.Errorf("failed to count file: %s | %w", path, readErr)
		}
		total += countEffectiveLines(content)
	}
	return total, nil
}

func countFileItem(projectRoot string, item worktreeFileItem) (int, error) {
	absolutePath := filepath.Join(projectRoot, filepath.FromSlash(item.Path))
	content, err := os.ReadFile(absolutePath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return 0, nil
		}
		return 0, fmt.Errorf("failed to count file: %s | %w", absolutePath, err)
	}

	total := 0
	if strings.HasSuffix(strings.ToLower(item.Path), ".lua") {
		total = countEffectiveLines(content)
	}
	return total + item.ExtraLinesIfExist, nil
}

func collectDirectoryLuaFiles(projectRoot, relativePath string) ([]string, error) {
	files, err := collectGitLuaFiles(projectRoot, relativePath)
	if err == nil {
		return files, nil
	}

	absoluteRoot := filepath.Join(projectRoot, filepath.FromSlash(relativePath))
	if _, statErr := os.Stat(absoluteRoot); statErr != nil {
		if errors.Is(statErr, os.ErrNotExist) {
			return []string{}, nil
		}
		return nil, statErr
	}

	collected := []string{}
	walkErr := filepath.WalkDir(absoluteRoot, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}
		if strings.EqualFold(filepath.Ext(entry.Name()), ".lua") {
			collected = append(collected, path)
		}
		return nil
	})
	if walkErr != nil {
		return nil, walkErr
	}
	sort.Strings(collected)
	return collected, nil
}

func collectGitLuaFiles(projectRoot, relativePath string) ([]string, error) {
	output, err := runCommand(projectRoot, nil, "git", "-C", projectRoot, "ls-files", "--", relativePath)
	if err != nil {
		return nil, err
	}

	files := []string{}
	for _, line := range splitLines(output) {
		normalized := strings.TrimSpace(line)
		if normalized == "" || !strings.HasSuffix(strings.ToLower(normalized), ".lua") {
			continue
		}
		files = append(files, filepath.Join(projectRoot, filepath.FromSlash(normalized)))
	}
	sort.Strings(files)
	return files, nil
}

func getCommits(gitRoot, since string) ([]commitInfo, error) {
	output, err := runCommand("", nil, "git", "-C", gitRoot, "log", "--since="+since, "--format=%H|%ci|%s", "--reverse")
	if err != nil {
		return nil, err
	}

	commits := []commitInfo{}
	for _, line := range splitLines(output) {
		normalized := strings.TrimSpace(line)
		if normalized == "" {
			continue
		}
		parts := strings.SplitN(normalized, "|", 3)
		if len(parts) != 3 {
			continue
		}
		hash := parts[0]
		if len(hash) < 8 {
			continue
		}
		commits = append(commits, commitInfo{
			Hash:     hash[:8],
			FullHash: hash,
			Date:     parts[1],
			Message:  parts[2],
		})
	}
	return commits, nil
}

func listCommitEntries(gitRoot, commitHash string) ([]treeEntry, error) {
	output, err := runCommand("", nil, "git", "-C", gitRoot, "ls-tree", "-r", commitHash, "src", "tests", "spec")
	if err != nil {
		return nil, err
	}

	entries := []treeEntry{}
	for _, line := range splitLines(output) {
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}
		objectType := fields[1]
		objectID := fields[2]
		filePath := strings.Join(fields[3:], " ")
		bucket := classifyBucket(filePath)
		if objectType != "blob" || bucket == "" {
			continue
		}
		entries = append(entries, treeEntry{
			Bucket:   bucket,
			ObjectID: objectID,
			FilePath: filePath,
		})
	}
	return entries, nil
}

func listDiffEntries(gitRoot, previousHash, currentHash string) ([]diffEntry, error) {
	output, err := runCommand("", nil, "git", "-C", gitRoot, "diff-tree", "-r", "--raw", "--no-commit-id", "-M", previousHash, currentHash, "--", "src", "tests", "spec")
	if err != nil {
		return nil, err
	}

	entries := []diffEntry{}
	for _, line := range splitLines(output) {
		normalized := strings.TrimSpace(line)
		if normalized == "" {
			continue
		}
		tabIndex := strings.IndexRune(normalized, '\t')
		if tabIndex < 0 {
			return nil, fmt.Errorf("unexpected git diff-tree raw line: %s", normalized)
		}
		header := normalized[:tabIndex]
		pathData := normalized[tabIndex+1:]
		headerFields := strings.Fields(header)
		if len(headerFields) < 5 {
			return nil, fmt.Errorf("unexpected git diff-tree raw line: %s", normalized)
		}

		status := headerFields[4]
		oldPath := pathData
		newPath := pathData
		statusCode := status[:1]
		if statusCode == "R" || statusCode == "C" {
			paths := strings.SplitN(pathData, "\t", 2)
			if len(paths) != 2 {
				return nil, fmt.Errorf("unexpected git rename diff line: %s", normalized)
			}
			oldPath = paths[0]
			newPath = paths[1]
		}

		entries = append(entries, diffEntry{
			OldObjectID: headerFields[2],
			NewObjectID: headerFields[3],
			OldPath:     oldPath,
			NewPath:     newPath,
		})
	}
	return entries, nil
}

func buildStateFromEntries(gitRoot, commitHash string, entries []treeEntry, cache map[string]blobStats) (*historyState, error) {
	missing := uniqueMissingObjectIDs(entries, cache)
	if len(missing) > 0 {
		if err := populateBlobStatsCache(gitRoot, missing, cache); err != nil {
			if err := populateBlobStatsCacheSlow(gitRoot, commitHash, entries, cache); err != nil {
				return nil, err
			}
		}
	}

	state := &historyState{
		PathToEntry: map[string]stateEntry{},
	}
	for _, entry := range entries {
		addStateEntry(state, entry.FilePath, entry.Bucket, entry.ObjectID, cache)
	}
	return state, nil
}

func rebuildState(gitRoot, commitHash string, cache map[string]blobStats) (*historyState, error) {
	entries, err := listCommitEntries(gitRoot, commitHash)
	if err != nil {
		return nil, err
	}
	return buildStateFromEntries(gitRoot, commitHash, entries, cache)
}

func uniqueMissingObjectIDs(entries []treeEntry, cache map[string]blobStats) []string {
	seen := map[string]bool{}
	ids := []string{}
	for _, entry := range entries {
		if _, ok := cache[entry.ObjectID]; ok || seen[entry.ObjectID] {
			continue
		}
		seen[entry.ObjectID] = true
		ids = append(ids, entry.ObjectID)
	}
	return ids
}

func applyDiffEntries(state *historyState, entries []diffEntry, cache map[string]blobStats, gitRoot string) error {
	pending := []treeEntry{}
	seen := map[string]bool{}
	missing := []string{}

	for _, entry := range entries {
		removeStateEntry(state, entry.OldPath, cache)

		bucket := classifyBucket(entry.NewPath)
		if bucket == "" || isZeroObjectID(entry.NewObjectID) {
			continue
		}

		pending = append(pending, treeEntry{
			Bucket:   bucket,
			ObjectID: entry.NewObjectID,
			FilePath: entry.NewPath,
		})

		if _, ok := cache[entry.NewObjectID]; !ok && !seen[entry.NewObjectID] {
			seen[entry.NewObjectID] = true
			missing = append(missing, entry.NewObjectID)
		}
	}

	if len(missing) > 0 {
		if err := populateBlobStatsCache(gitRoot, missing, cache); err != nil {
			return err
		}
	}

	for _, entry := range pending {
		addStateEntry(state, entry.FilePath, entry.Bucket, entry.ObjectID, cache)
	}
	return nil
}

func makeHistoryRow(commit commitInfo, state *historyState) historyRow {
	return historyRow{
		Hash:       commit.Hash,
		Date:       commit.Date,
		Message:    commit.Message,
		SrcLoc:     state.SrcLoc,
		SrcFiles:   state.SrcFiles,
		TestsLoc:   state.TestsLoc,
		TestsFiles: state.TestsFiles,
		TotalLoc:   state.SrcLoc + state.TestsLoc,
		TotalFiles: state.SrcFiles + state.TestsFiles,
	}
}

func removeStateEntry(state *historyState, path string, cache map[string]blobStats) {
	entry, ok := state.PathToEntry[path]
	if !ok {
		return
	}
	stats := cache[entry.ObjectID]
	if stats.HasContent {
		if entry.Bucket == "src" {
			state.SrcLoc -= stats.LineCount
			state.SrcFiles--
		} else if entry.Bucket == "tests" {
			state.TestsLoc -= stats.LineCount
			state.TestsFiles--
		}
	}
	delete(state.PathToEntry, path)
}

func addStateEntry(state *historyState, path, bucket, objectID string, cache map[string]blobStats) {
	state.PathToEntry[path] = stateEntry{
		Bucket:   bucket,
		ObjectID: objectID,
	}
	stats := cache[objectID]
	if !stats.HasContent {
		return
	}
	if bucket == "src" {
		state.SrcLoc += stats.LineCount
		state.SrcFiles++
	} else if bucket == "tests" {
		state.TestsLoc += stats.LineCount
		state.TestsFiles++
	}
}

func populateBlobStatsCache(gitRoot string, objectIDs []string, cache map[string]blobStats) error {
	if len(objectIDs) == 0 {
		return nil
	}
	output, err := runCommand("", []byte(strings.Join(objectIDs, "\n")+"\n"), "git", "-C", gitRoot, "cat-file", "--batch")
	if err != nil {
		return err
	}

	stats, err := parseCatFileBatch([]byte(output), objectIDs)
	if err != nil {
		return err
	}
	for objectID, value := range stats {
		cache[objectID] = value
	}
	return nil
}

func populateBlobStatsCacheSlow(gitRoot, commitHash string, entries []treeEntry, cache map[string]blobStats) error {
	for _, entry := range entries {
		if _, ok := cache[entry.ObjectID]; ok {
			continue
		}
		output, err := runCommand("", nil, "git", "-C", gitRoot, "show", commitHash+":"+entry.FilePath)
		if err != nil {
			cache[entry.ObjectID] = blobStats{}
			continue
		}
		content := []byte(output)
		cache[entry.ObjectID] = blobStats{
			LineCount:  countEffectiveLines(content),
			HasContent: len(content) > 0,
		}
	}
	return nil
}

func parseCatFileBatch(output []byte, objectIDs []string) (map[string]blobStats, error) {
	stats := map[string]blobStats{}
	cursor := 0
	for _, objectID := range objectIDs {
		headerEnd := bytes.IndexByte(output[cursor:], '\n')
		if headerEnd < 0 {
			return nil, errors.New("git cat-file batch output ended unexpectedly")
		}
		header := string(output[cursor : cursor+headerEnd])
		headerFields := strings.Fields(header)
		if len(headerFields) != 3 {
			return nil, fmt.Errorf("unexpected git cat-file header: %s", header)
		}
		if headerFields[0] != objectID {
			return nil, fmt.Errorf("git cat-file batch order mismatch: expected %s got %s", objectID, headerFields[0])
		}
		if headerFields[1] != "blob" {
			return nil, fmt.Errorf("git cat-file returned non-blob object: %s", headerFields[0])
		}
		var size int
		if _, err := fmt.Sscanf(headerFields[2], "%d", &size); err != nil {
			return nil, fmt.Errorf("invalid git cat-file blob size: %s", headerFields[2])
		}

		contentStart := cursor + headerEnd + 1
		contentEnd := contentStart + size
		if contentEnd > len(output) {
			return nil, errors.New("git cat-file content ended unexpectedly")
		}

		content := output[contentStart:contentEnd]
		stats[objectID] = blobStats{
			LineCount:  countEffectiveLines(content),
			HasContent: size > 0,
		}
		cursor = contentEnd + 1
	}
	return stats, nil
}

func classifyBucket(path string) string {
	normalized := strings.ReplaceAll(path, "\\", "/")
	if !strings.HasSuffix(strings.ToLower(normalized), ".lua") {
		return ""
	}
	if strings.HasPrefix(normalized, "src/") {
		return "src"
	}
	if strings.HasPrefix(normalized, "tests/") || strings.HasPrefix(normalized, "spec/") {
		return "tests"
	}
	return ""
}

func isZeroObjectID(objectID string) bool {
	if objectID == "" {
		return true
	}
	for _, ch := range objectID {
		if ch != '0' {
			return false
		}
	}
	return true
}

func countEffectiveLines(content []byte) int {
	if len(content) == 0 {
		return 0
	}

	count := 0
	inBlockComment := false
	lineStart := 0

	for index := 0; index <= len(content); index++ {
		if index < len(content) && content[index] != '\n' {
			continue
		}

		line := content[lineStart:index]
		if len(line) > 0 && line[len(line)-1] == '\r' {
			line = line[:len(line)-1]
		}
		if lineHasCode(line, &inBlockComment) {
			count++
		}
		lineStart = index + 1
	}

	return count
}

func lineHasCode(line []byte, inBlockComment *bool) bool {
	current := append([]byte(nil), line...)

	for {
		if *inBlockComment {
			blockEnd := bytes.Index(current, []byte("]]"))
			if blockEnd < 0 {
				current = current[:0]
				break
			}
			current = current[blockEnd+2:]
			*inBlockComment = false
			continue
		}

		blockStart := bytes.Index(current, []byte("--[["))
		lineStart := bytes.Index(current, []byte("--"))
		if lineStart < 0 {
			break
		}

		if blockStart >= 0 && blockStart == lineStart {
			beforeComment := append([]byte(nil), current[:blockStart]...)
			blockEnd := bytes.Index(current[blockStart+4:], []byte("]]"))
			if blockEnd >= 0 {
				current = append(beforeComment, current[blockStart+4+blockEnd+2:]...)
				continue
			}
			current = beforeComment
			*inBlockComment = true
			break
		}

		current = current[:lineStart]
		break
	}

	for _, ch := range current {
		if ch != ' ' && ch != '\t' && ch != '\r' && ch != '\n' && ch != '\v' && ch != '\f' {
			return true
		}
	}
	return false
}

func splitLines(text string) []string {
	text = strings.ReplaceAll(text, "\r\n", "\n")
	text = strings.ReplaceAll(text, "\r", "\n")
	lines := strings.Split(text, "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	return lines
}

func runCommand(dir string, stdin []byte, name string, args ...string) (string, error) {
	command := exec.Command(name, args...)
	if dir != "" {
		command.Dir = dir
	}
	if stdin != nil {
		command.Stdin = bytes.NewReader(stdin)
	}

	output, err := command.CombinedOutput()
	if err != nil {
		text := strings.TrimSpace(string(output))
		if text == "" {
			text = err.Error()
		}
		return "", errors.New(text)
	}
	return string(output), nil
}

func mustLoadJSON(path string, target any) {
	content, err := os.ReadFile(path)
	if err != nil {
		fail(err.Error())
	}
	if err := json.Unmarshal(content, target); err != nil {
		fail(err.Error())
	}
}

func mustWriteJSON(value any) {
	encoder := json.NewEncoder(os.Stdout)
	if err := encoder.Encode(value); err != nil {
		fail(err.Error())
	}
}

func fail(message string) {
	_, _ = io.WriteString(os.Stderr, strings.TrimSpace(message)+"\n")
	os.Exit(1)
}
