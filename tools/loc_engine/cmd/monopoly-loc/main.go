package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
)

const algorithmVersion = "v1"

type historyRequest struct {
	GitRoot string `json:"git_root"`
	Days    int    `json:"days"`
}

type historyResponse struct {
	Rows []historyRow `json:"rows"`
}

type historyRow struct {
	Date       string `json:"date"`
	Hash       string `json:"hash"`
	Message    string `json:"message"`
	SrcLoc     int    `json:"src_loc"`
	SrcFiles   int    `json:"src_files"`
	TestsLoc   int    `json:"tests_loc"`
	TestsFiles int    `json:"tests_files"`
	TotalLoc   int    `json:"total_loc"`
	TotalFiles int    `json:"total_files"`
	CarriedFwd bool   `json:"carried_forward"`
}

type commitInfo struct {
	Hash     string
	FullHash string
	Date     string
	DateOnly string
	Message  string
}

type treeEntry struct {
	Bucket   string
	ObjectID string
	FilePath string
}

type blobStats struct {
	LineCount  int
	HasContent bool
}

type historyState struct {
	SrcLoc     int
	SrcFiles   int
	TestsLoc   int
	TestsFiles int
}

type diskCache struct {
	AlgorithmVersion string                      `json:"algorithm_version"`
	Entries          map[string]diskCacheEntry   `json:"entries"`
}

type diskCacheEntry struct {
	LineCount  int  `json:"line_count"`
	HasContent bool `json:"has_content"`
}

func main() {
	if len(os.Args) < 4 || os.Args[1] != "history" || os.Args[2] != "--request-json" {
		fail("usage: monopoly-loc history --request-json <path>")
	}

	requestPath := os.Args[3]
	var request historyRequest
	mustLoadJSON(requestPath, &request)
	response, err := countHistoryDaily(request)
	if err != nil {
		fail(err.Error())
	}
	mustWriteJSON(response)
}

func countHistoryDaily(request historyRequest) (historyResponse, error) {
	gitRoot := strings.TrimSpace(request.GitRoot)
	if gitRoot == "" {
		gitRoot = "."
	}
	days := request.Days
	if days <= 0 {
		days = 14
	}

	since := fmt.Sprintf("%d days ago", days)
	commits, err := getCommits(gitRoot, since)
	if err != nil {
		return historyResponse{}, err
	}
	if len(commits) == 0 {
		return historyResponse{Rows: []historyRow{}}, nil
	}

	dayCommits := groupByDay(commits)
	dayKeys := make([]string, 0, len(dayCommits))
	for day := range dayCommits {
		dayKeys = append(dayKeys, day)
	}
	sort.Strings(dayKeys)

	cache := &sync.Map{}
	loadDiskCache(gitRoot, cache)

	results := make([]dayResult, len(dayKeys))
	workerCount := runtime.NumCPU()
	if workerCount > 8 {
		workerCount = 8
	}
	if workerCount < 1 {
		workerCount = 1
	}

	indexChan := make(chan int)
	var workerWg sync.WaitGroup
	for w := 0; w < workerCount; w++ {
		workerWg.Add(1)
		go func() {
			defer workerWg.Done()
			for index := range indexChan {
				day := dayKeys[index]
				commit := dayCommits[day]
				state, computeErr := buildDayState(gitRoot, commit.FullHash, cache)
				if computeErr != nil {
					results[index] = dayResult{err: computeErr}
					continue
				}
				results[index] = dayResult{row: historyRow{
					Date:       day,
					Hash:       commit.Hash,
					Message:    commit.Message,
					SrcLoc:     state.SrcLoc,
					SrcFiles:   state.SrcFiles,
					TestsLoc:   state.TestsLoc,
					TestsFiles: state.TestsFiles,
					TotalLoc:   state.SrcLoc + state.TestsLoc,
					TotalFiles: state.SrcFiles + state.TestsFiles,
				}}
			}
		}()
	}
	for index := range dayKeys {
		indexChan <- index
	}
	close(indexChan)
	workerWg.Wait()

	for _, result := range results {
		if result.err != nil {
			return historyResponse{}, result.err
		}
	}

	saveDiskCache(gitRoot, cache)

	return historyResponse{Rows: carryForward(dayKeys, results)}, nil
}

func groupByDay(commits []commitInfo) map[string]commitInfo {
	// commits arrive in chronological order (getCommits passes git log --reverse),
	// so unconditional assignment keeps the last commit of each day as the snapshot.
	dayCommits := map[string]commitInfo{}
	for _, commit := range commits {
		dayCommits[commit.DateOnly] = commit
	}
	return dayCommits
}

func carryForward(dayKeys []string, results []dayResult) []historyRow {
	if len(dayKeys) == 0 {
		return []historyRow{}
	}
	rowByDay := map[string]historyRow{}
	for index, day := range dayKeys {
		rowByDay[day] = results[index].row
	}

	firstDay := parseISODate(dayKeys[0])
	lastDay := parseISODate(dayKeys[len(dayKeys)-1])
	totalDays := daysBetween(firstDay, lastDay) + 1

	rows := make([]historyRow, 0, totalDays)
	var lastSeen historyRow
	haveLastSeen := false
	for offset := 0; offset < totalDays; offset++ {
		day := formatISODate(addDays(firstDay, offset))
		if actual, ok := rowByDay[day]; ok {
			rows = append(rows, actual)
			lastSeen = actual
			haveLastSeen = true
		} else if haveLastSeen {
			carried := lastSeen
			carried.Date = day
			carried.Hash = ""
			carried.Message = ""
			carried.CarriedFwd = true
			rows = append(rows, carried)
		}
	}
	return rows
}

type dayResult struct {
	row historyRow
	err error
}

func buildDayState(gitRoot, commitHash string, cache *sync.Map) (*historyState, error) {
	entries, err := listCommitEntries(gitRoot, commitHash)
	if err != nil {
		return nil, err
	}

	missing := uniqueMissingObjectIDs(entries, cache)
	if len(missing) > 0 {
		if err := populateBlobStatsCache(gitRoot, missing, cache); err != nil {
			if err := populateBlobStatsCacheSlow(gitRoot, commitHash, entries, cache); err != nil {
				return nil, err
			}
		}
	}

	state := &historyState{}
	for _, entry := range entries {
		statsValue, ok := cache.Load(entry.ObjectID)
		if !ok {
			continue
		}
		stats := statsValue.(blobStats)
		if !stats.HasContent {
			continue
		}
		switch entry.Bucket {
		case "src":
			state.SrcLoc += stats.LineCount
			state.SrcFiles++
		case "tests":
			state.TestsLoc += stats.LineCount
			state.TestsFiles++
		}
	}
	return state, nil
}

func uniqueMissingObjectIDs(entries []treeEntry, cache *sync.Map) []string {
	seen := map[string]bool{}
	ids := []string{}
	for _, entry := range entries {
		if _, ok := cache.Load(entry.ObjectID); ok {
			continue
		}
		if seen[entry.ObjectID] {
			continue
		}
		seen[entry.ObjectID] = true
		ids = append(ids, entry.ObjectID)
	}
	return ids
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
		date := parts[1]
		dateOnly := date
		if len(dateOnly) >= 10 {
			dateOnly = dateOnly[:10]
		}
		commits = append(commits, commitInfo{
			Hash:     hash[:8],
			FullHash: hash,
			Date:     date,
			DateOnly: dateOnly,
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

func populateBlobStatsCache(gitRoot string, objectIDs []string, cache *sync.Map) error {
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
		cache.Store(objectID, value)
	}
	return nil
}

func populateBlobStatsCacheSlow(gitRoot, commitHash string, entries []treeEntry, cache *sync.Map) error {
	for _, entry := range entries {
		if _, ok := cache.Load(entry.ObjectID); ok {
			continue
		}
		output, err := runCommand("", nil, "git", "-C", gitRoot, "show", commitHash+":"+entry.FilePath)
		if err != nil {
			cache.Store(entry.ObjectID, blobStats{})
			continue
		}
		content := []byte(output)
		cache.Store(entry.ObjectID, blobStats{
			LineCount:  countEffectiveLines(content),
			HasContent: len(content) > 0,
		})
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

func cachePath(gitRoot string) string {
	return filepath.Join(gitRoot, ".loc", "cache", "blob_stats.json")
}

func loadDiskCache(gitRoot string, cache *sync.Map) {
	path := cachePath(gitRoot)
	content, err := os.ReadFile(path)
	if err != nil {
		return
	}
	var disk diskCache
	if err := json.Unmarshal(content, &disk); err != nil {
		return
	}
	if disk.AlgorithmVersion != algorithmVersion {
		return
	}
	for objectID, entry := range disk.Entries {
		cache.Store(objectID, blobStats{
			LineCount:  entry.LineCount,
			HasContent: entry.HasContent,
		})
	}
}

func saveDiskCache(gitRoot string, cache *sync.Map) {
	disk := diskCache{
		AlgorithmVersion: algorithmVersion,
		Entries:          map[string]diskCacheEntry{},
	}
	cache.Range(func(key, value any) bool {
		objectID, ok := key.(string)
		if !ok {
			return true
		}
		stats, ok := value.(blobStats)
		if !ok {
			return true
		}
		disk.Entries[objectID] = diskCacheEntry{
			LineCount:  stats.LineCount,
			HasContent: stats.HasContent,
		}
		return true
	})

	payload, err := json.Marshal(disk)
	if err != nil {
		return
	}

	path := cachePath(gitRoot)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return
	}
	tmpPath := path + ".tmp"
	if err := os.WriteFile(tmpPath, payload, 0o644); err != nil {
		return
	}
	_ = os.Rename(tmpPath, path)
}

func parseISODate(date string) [3]int {
	var year, month, day int
	if _, err := fmt.Sscanf(date, "%d-%d-%d", &year, &month, &day); err != nil {
		return [3]int{}
	}
	return [3]int{year, month, day}
}

func formatISODate(date [3]int) string {
	return fmt.Sprintf("%04d-%02d-%02d", date[0], date[1], date[2])
}

func daysBetween(a, b [3]int) int {
	return julianDay(b) - julianDay(a)
}

func addDays(date [3]int, offset int) [3]int {
	j := julianDay(date) + offset
	return julianToDate(j)
}

func julianDay(date [3]int) int {
	y, m, d := date[0], date[1], date[2]
	if m <= 2 {
		y -= 1
		m += 12
	}
	a := y / 100
	b := 2 - a + a/4
	return int(float64(365.25*float64(y+4716))) + int(float64(30.6001*float64(m+1))) + d + b - 1524
}

func julianToDate(jd int) [3]int {
	a := jd + 32044
	b := (4*a + 3) / 146097
	c := a - (146097*b)/4
	d := (4*c + 3) / 1461
	e := c - (1461*d)/4
	m := (5*e + 2) / 153
	day := e - (153*m+2)/5 + 1
	month := m + 3 - 12*(m/10)
	year := 100*b + d - 4800 + m/10
	return [3]int{year, month, day}
}
