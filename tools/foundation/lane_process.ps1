param([string]$CommandPath, [string]$OutputPath, [string]$StatusPath, [double]$Timeout)
$ErrorActionPreference = 'Stop'
# Windows PowerShell/.NET compiler is built in; no external compiler or SDK.
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
public static class LaneProcess {
  const uint INFINITE = 0xffffffff, WAIT_TIMEOUT = 258;
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Startup {
    public int cb; public string reserved, desktop, title;
    public uint x,y,xsize,ysize,xchars,ychars,fill,flags;
    public ushort show, reservedSize; public IntPtr reserved2, input, output, error;
  }
  [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr process, thread; public uint pid, tid; }
  [StructLayout(LayoutKind.Sequential)] struct Security { public int size; public IntPtr descriptor; public int inherit; }
  [StructLayout(LayoutKind.Sequential)] struct BasicLimits {
    public long processTime,jobTime; public uint flags; public UIntPtr min,max;
    public uint active; public UIntPtr affinity; public uint priority,scheduling;
  }
  [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong a,b,c,d,e,f; }
  [StructLayout(LayoutKind.Sequential)] struct Limits {
    public BasicLimits basic; public IoCounters io; public UIntPtr processMemory,jobMemory,peakProcess,peakJob;
  }
  [StructLayout(LayoutKind.Sequential)] struct Accounting {
    public long user,kernel,periodUser,periodKernel; public uint faults,total,active,terminated;
  }
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr security,string name);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int info,ref Limits limits,uint length);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job,int info,out Accounting accounting,uint length,IntPtr returned);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateJobObject(IntPtr job,uint code);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateProcess(IntPtr process,uint code);
  [DllImport("kernel32.dll", SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
  [DllImport("kernel32.dll", SetLastError=true)] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr handle);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateFile(string name,uint access,uint sharing,ref Security security,uint disposition,uint flags,IntPtr template);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcess(string app,StringBuilder command,IntPtr psecurity,IntPtr tsecurity,bool inherit,uint flags,IntPtr environment,string cwd,ref Startup startup,out ProcessInfo process);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool MoveFileEx(string source,string target,uint flags);
  static uint Error() { return unchecked((uint)Marshal.GetLastWin32Error()); }
  static bool Invalid(IntPtr h) { return h == IntPtr.Zero || h == new IntPtr(-1); }
  static void Publish(string path,uint code,string reason) {
    File.WriteAllText(path+".done",code+" "+reason+"\n",new UTF8Encoding(false));
    if (!MoveFileEx(path+".done",path,9)) throw new IOException("Completion publish failed: "+Error());
  }
  public static void Run(string commandPath,string outputPath,string statusPath,double timeout) {
    IntPtr job=IntPtr.Zero,output=IntPtr.Zero,input=IntPtr.Zero;
    ProcessInfo process=new ProcessInfo(); uint code=1; string reason="exit";
    bool safe=true;
    try {
      job=CreateJobObject(IntPtr.Zero,null);
      if (Invalid(job)) throw new IOException("CreateJobObject: "+Error());
      Limits limits=new Limits(); limits.basic.flags=0x2000;
      if (!SetInformationJobObject(job,9,ref limits,(uint)Marshal.SizeOf(typeof(Limits)))) throw new IOException("SetInformationJobObject: "+Error());
      Security security=new Security(); security.size=Marshal.SizeOf(typeof(Security)); security.inherit=1;
      output=CreateFile(outputPath,0x40000000,1,ref security,2,0,IntPtr.Zero);
      input=CreateFile("NUL",0x80000000,3,ref security,3,0,IntPtr.Zero);
      if (Invalid(output) || Invalid(input)) throw new IOException("CreateFile: "+Error());
      Startup startup=new Startup(); startup.cb=Marshal.SizeOf(typeof(Startup)); startup.flags=0x100;
      startup.input=input; startup.output=output; startup.error=output;
      string cmd=Environment.GetEnvironmentVariable("ComSpec") ?? "C:\\Windows\\System32\\cmd.exe";
      StringBuilder command=new StringBuilder("\""+cmd+"\" /d /v:off /s /c \"\""+commandPath+"\"\"");
      if (!CreateProcess(cmd,command,IntPtr.Zero,IntPtr.Zero,true,0x08000004,IntPtr.Zero,null,ref startup,out process)) throw new IOException("CreateProcess: "+Error());
      if (!AssignProcessToJobObject(job,process.process)) {
        code=Error(); reason="launch_failed";
        safe=TerminateProcess(process.process,code) && WaitForSingleObject(process.process,10000)==0;
      } else {
        File.WriteAllText(statusPath+".pid",System.Diagnostics.Process.GetCurrentProcess().Id+" "+process.pid+"\n");
        var clock=System.Diagnostics.Stopwatch.StartNew();
        if (ResumeThread(process.thread)==INFINITE) throw new IOException("ResumeThread: "+Error());
        uint wait=WaitForSingleObject(process.process,(uint)Math.Min(timeout*1000,INFINITE-1));
        if (wait==WAIT_TIMEOUT) { code=124; reason="timeout"; }
        else if (wait!=0) throw new IOException("WaitForSingleObject: "+Error());
        else {
          if (!GetExitCodeProcess(process.process,out code)) throw new IOException("GetExitCodeProcess: "+Error());
          if (code==9009) reason="launch_failed";
          for (;;) {
            Accounting accounting;
            if (!QueryInformationJobObject(job,1,out accounting,(uint)Marshal.SizeOf(typeof(Accounting)),IntPtr.Zero)) throw new IOException("QueryInformationJobObject: "+Error());
            if (accounting.active==0) break;
            if (clock.Elapsed.TotalSeconds>=timeout) { code=124; reason="timeout"; break; }
            System.Threading.Thread.Sleep(10);
          }
        }
      }
    } catch(Exception error) {
      code=1; reason="launch_failed";
      File.WriteAllText(statusPath+".error",error.ToString(),new UTF8Encoding(false));
    } finally {
      if (!Invalid(job) && !Invalid(process.process)) {
        if (!TerminateJobObject(job,code)) safe=false;
        var stop=System.Diagnostics.Stopwatch.StartNew();
        for (;;) {
          Accounting accounting;
          if (!QueryInformationJobObject(job,1,out accounting,(uint)Marshal.SizeOf(typeof(Accounting)),IntPtr.Zero)) { safe=false; break; }
          if (accounting.active==0) break;
          if (stop.Elapsed.TotalSeconds>=10) { safe=false; break; }
          System.Threading.Thread.Sleep(10);
        }
      }
      if (!Invalid(job)) CloseHandle(job);
      if (!Invalid(process.thread)) CloseHandle(process.thread);
      if (!Invalid(process.process)) CloseHandle(process.process);
      if (!Invalid(input)) CloseHandle(input);
      if (!Invalid(output)) CloseHandle(output);
      if (!safe) { code=1460; reason="termination_failed"; }
      Publish(statusPath,code,reason);
    }
  }
}
'@
[LaneProcess]::Run($CommandPath, $OutputPath, $StatusPath, $Timeout)
