/* Native Windows lane owner: only the process created here enters our job. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

static void publish(const wchar_t *path, DWORD code, const char *reason) {
    wchar_t temporary[32768];
    FILE *file;
    swprintf(temporary, 32768, L"%ls.done", path);
    file = _wfopen(temporary, L"wb");
    if (!file) return;
    fprintf(file, "%lu %s\n", (unsigned long)code, reason);
    fclose(file);
    MoveFileExW(temporary, path, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
}

int wmain(int argc, wchar_t **argv) {
    HANDLE job, output, input;
    STARTUPINFOW startup = {0};
    PROCESS_INFORMATION process = {0};
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    SECURITY_ATTRIBUTES security = {sizeof(SECURITY_ATTRIBUTES), NULL, TRUE};
    wchar_t command[32768];
    DWORD code = 1, wait;
    ULONGLONG lane_deadline;
    const char *reason = "exit";
    if (argc != 5) return 2;
    job = CreateJobObjectW(NULL, NULL);
    if (!job) { publish(argv[3], GetLastError(), "launch_failed"); return 1; }
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) {
        publish(argv[3], GetLastError(), "launch_failed"); CloseHandle(job); return 1;
    }
    output = CreateFileW(argv[2], GENERIC_WRITE, FILE_SHARE_READ, &security, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    input = CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (output == INVALID_HANDLE_VALUE || input == INVALID_HANDLE_VALUE) {
        code = GetLastError();
        if (input != INVALID_HANDLE_VALUE) CloseHandle(input);
        if (output != INVALID_HANDLE_VALUE) CloseHandle(output);
        CloseHandle(job); publish(argv[3], code, "launch_failed"); return 1;
    }
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdOutput = startup.hStdError = output;
    startup.hStdInput = input;
    swprintf(command, 32768, L"cmd.exe /d /v:off /s /c \"\"%ls\"\"", argv[1]);
    if (!CreateProcessW(NULL, command, NULL, NULL, TRUE, CREATE_SUSPENDED | CREATE_NO_WINDOW, NULL, NULL, &startup, &process)) {
        code = GetLastError(); reason = "launch_failed";
    } else if (!AssignProcessToJobObject(job, process.hProcess)) {
        code = GetLastError(); reason = "launch_failed";
        TerminateProcess(process.hProcess, code);
        if (WaitForSingleObject(process.hProcess, 10000) != WAIT_OBJECT_0) reason = "termination_failed";
    } else {
        FILE *identity;
        wchar_t identity_path[32768];
        swprintf(identity_path, 32768, L"%ls.pid", argv[3]);
        identity = _wfopen(identity_path, L"wb");
        if (identity) { fprintf(identity, "%lu %lu\n", (unsigned long)GetCurrentProcessId(), (unsigned long)process.dwProcessId); fclose(identity); }
        lane_deadline = GetTickCount64() + (DWORD)(_wtof(argv[4]) * 1000.0);
        ResumeThread(process.hThread);
        wait = WaitForSingleObject(process.hProcess, (DWORD)(_wtof(argv[4]) * 1000.0));
        if (wait == WAIT_TIMEOUT) {
            reason = "timeout"; code = 124;
            TerminateJobObject(job, code);
            if (WaitForSingleObject(process.hProcess, 10000) != WAIT_OBJECT_0) reason = "termination_failed";
        } else if (wait == WAIT_OBJECT_0) {
            GetExitCodeProcess(process.hProcess, &code);
            if (code == 9009) reason = "launch_failed";
            /* A detached owned writer must finish before its output is read. */
            for (;;) {
                JOBOBJECT_BASIC_ACCOUNTING_INFORMATION accounting = {0};
                if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &accounting, sizeof(accounting), NULL)) {
                    code = GetLastError(); reason = "termination_failed"; break;
                }
                if (accounting.ActiveProcesses == 0) break;
                if (GetTickCount64() >= lane_deadline) { code = 124; reason = "timeout"; break; }
                Sleep(10);
            }
        } else {
            code = GetLastError(); reason = "launch_failed";
            TerminateJobObject(job, code);
            if (WaitForSingleObject(process.hProcess, 10000) != WAIT_OBJECT_0) reason = "termination_failed";
        }
    }
    /* Stop and wait for owned descendants before closing output/publishing. */
    if (process.hProcess) {
        JOBOBJECT_BASIC_ACCOUNTING_INFORMATION accounting = {0};
        ULONGLONG deadline = GetTickCount64() + 10000;
        if (!TerminateJobObject(job, code)) { code = GetLastError(); reason = "termination_failed"; }
        for (;;) {
            if (!QueryInformationJobObject(job, JobObjectBasicAccountingInformation, &accounting, sizeof(accounting), NULL)) {
                code = GetLastError(); reason = "termination_failed"; break;
            }
            if (accounting.ActiveProcesses == 0) break;
            if (GetTickCount64() >= deadline) { code = 1460; reason = "termination_failed"; break; }
            Sleep(10);
        }
    }
    CloseHandle(job);
    if (process.hThread) CloseHandle(process.hThread);
    if (process.hProcess) CloseHandle(process.hProcess);
    CloseHandle(input);
    CloseHandle(output);
    publish(argv[3], code, reason);
    return 0;
}
