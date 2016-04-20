using System;
using System.Collections.Generic;
using System.Text;
using System.Management.Automation;

namespace PoshRS.PowerShell
{
    public class V2UsingVariable
    {
        public string Name;
        public string NewName;
        public object Value;
        public string NewVarName;
    }
    public class RSRunspacePool
    {
        public System.Management.Automation.Runspaces.RunspacePool RunspacePool;
        public System.Management.Automation.Runspaces.RunspacePoolState State;
        public int AvailableJobs;
        public int MaxJobs;
        public DateTime LastActivity = DateTime.MinValue;
        public System.Guid RunspacePoolID;
        public bool CanDispose = false;
    }
    public class RSJob
    {
        public string Name;
        public int ID;
        public System.Management.Automation.PSInvocationState State;
        public System.Guid InstanceID;
        public object Handle;
        public object Runspace;
        public System.Management.Automation.PowerShell InnerJob;
        public System.Threading.ManualResetEvent Finished;
        public string Command;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.ErrorRecord> Error;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.VerboseRecord> Verbose;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.DebugRecord> Debug;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.WarningRecord> Warning;
        public System.Management.Automation.PSDataCollection<System.Management.Automation.ProgressRecord> Progress;
        public bool HasMoreData;
        public bool HasErrors;
        public object Output;
        public System.Guid RunspacePoolID;
        public bool Completed = false;
        public string Batch;
    }
}
