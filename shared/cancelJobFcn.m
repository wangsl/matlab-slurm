function OK = cancelJobFcn(cluster, job)
%CANCELJOBFCN Cancels a job on Slurm
%
% Set your cluster's PluginScriptsLocation to the parent folder of this
% function to run it when you cancel a job.

% Copyright 2010-2018 The MathWorks, Inc.

%fprintf('to cancel job\n');
%fprintf('SLURM_JOBID=%s\n', getenv('SLURM_JOBID'))
%fprintf('SLURM_STEPID=%s\n', getenv('SLURM_STEPID'))

cmdToRun = sprintf('bash %s/scancel.sh', cluster.IntegrationScriptsLocation);

fprintf('Command to cancel job: %s\n', cmdToRun);

system(cmdToRun);

return;

% Store the current filename for the errors, warnings and dctSchedulerMessages
currFilename = mfilename;
if ~isa(cluster, 'parallel.Cluster')
    error('parallelexamples:GenericSLURM:SubmitFcnError', ...
        'The function %s is for use with clusters created using the parcluster command.', currFilename)
end
if ~cluster.HasSharedFilesystem
    error('parallelexamples:GenericSLURM:NotSharedFileSystem', ...
        'The function %s is for use with shared filesystems.', currFilename)
end
% Get the information about the actual cluster used
data = cluster.getJobClusterData(job);
if isempty(data)
    % This indicates that the job has not been submitted, so return true
    dctSchedulerMessage(1, '%s: Job cluster data was empty for job with ID %d.', currFilename, job.ID);
    OK = true;
    return
end
try
    jobIDs = job.getTaskSchedulerIDs();
catch err
    ex = MException('parallelexamples:GenericSLURM:FailedToRetrieveJobID', ...
        'Failed to retrieve clusters''s job IDs from the tasks.');
    ex = ex.addCause(err);
    throw(ex);
end

% Only ask the cluster to cancel the job if it is hasn't reached a terminal
% state.
erroredJobAndCauseStrings = cell(size(jobIDs));
jobState = job.State;
if ~(strcmp(jobState, 'finished') || strcmp(jobState, 'failed'))
    % Get the cluster to delete the job
    for ii = 1:length(jobIDs)
        jobID = jobIDs{ii};
        commandToRun = sprintf('scancel ''%s''', jobID);
        dctSchedulerMessage(4, '%s: Canceling job on cluster using command:\n\t%s.', currFilename, commandToRun);
        try
            % Make the shelled out call to run the command.
            [cmdFailed, cmdOut] = system(commandToRun);
        catch err
            cmdFailed = true;
            cmdOut = err.message;
        end
        
        if cmdFailed
            % Keep track of all jobs that errored when being cancelled.
            % We'll report these later on.
            erroredJobAndCauseStrings{ii} = sprintf('Job ID: %s\tReason: %s', jobID, strtrim(cmdOut));
            dctSchedulerMessage(1, '%s: Failed to cancel job %s on cluster.  Reason:\n\t%s', currFilename, jobID, cmdOut);
        end
    end
end

% Now warn about those jobs that we failed to cancel.
erroredJobAndCauseStrings = erroredJobAndCauseStrings(~cellfun(@isempty, erroredJobAndCauseStrings));
if ~isempty(erroredJobAndCauseStrings)
    warning('parallelexamples:GenericSLURM:FailedToCancelJob', ...
        'Failed to cancel the following jobs on the cluster:\n%s', ...
        sprintf('  %s\n', erroredJobAndCauseStrings{:}));
end
OK = isempty(erroredJobAndCauseStrings);
