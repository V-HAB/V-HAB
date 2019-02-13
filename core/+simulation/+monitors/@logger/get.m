function [ mfData, afTime, atConfiguration ] = get(this, aiIndexes, sIntervalMode, fIntervalValue)
%GET Retrieves data from log for selected items
% This method gets the actual logged data from the mfLog property in
% addition to the configuration data struct and returns both in arrays. The
% aiIndex input parameters is an array of integers representing the log
% item's indexes in the mfLog matrix.

% First we need get the actual last tick of the simulation. We need the
% last tick so we can truncate the mfLog data, because it is preallocated,
% meaning there are most likely hundreds of rows filled with NaNs at the
% end, that would mess up everything. We need to add one to the last tick
% because the log also contains data for tick 0. 
iTick = this.oSimulationInfrastructure.oSimulationContainer.oTimer.iTick + 1;
mfLogTmp = this.mfLog(1:iTick, :);

% We now initialize our return array with NaNs
mfData = nan(size(mfLogTmp, 1), length(aiIndexes));

% Going through each of the indexes being queried and getting the
% information
for iI = 1:length(aiIndexes)
    % For easier reading we get the current index into a local variable.
    iIndex = aiIndexes(iI);
    
    % If the index is smaller than zero, this indicates that we are dealing
    % with a virtual value; one that was not logged directly, but
    % calculated from other logged values. We have to do some additional
    % stuff here.
    if iIndex < 0
        % First we can get the configuration struct from the tVirtualValues
        % property.
        tConfiguration  = this.tVirtualValues(-1 * iIndex);
        
        % Now we have to preset some values in tConfiguration that are
        % present in regularly logged values but not virtual ones.
        tConfiguration.sObjUuid    = [];
        tConfiguration.sObjectPath = [];
        tConfiguration.iIndex      = iIndex;
        
        % Using the function handle stored with the virtual value we now
        % perform the calculations that are to be made here.
        afData = tConfiguration.calculationHandle(mfLogTmp);
        
        % Finally, to be equal to a normally logged value, we remove field
        % containing the function handle.
        tConfiguration = rmfield(tConfiguration, 'calculationHandle');
    else
        % The current index is not a virtual value so we can just copy the
        % data from the log matrix and the tLogValues property.
        afData = mfLogTmp(:, iIndex);
        tConfiguration  = this.tLogValues(iIndex);
    end
    
    % Copying the data from the current index into the return variable.
    mfData(:, iI) = afData;
    
    % If this is the first loop iteration, we initialize the return
    % variable for the configuration data here. If it's a following
    % iteration, we append the array.
    if iI == 1
        atConfiguration = tConfiguration;
    else
        atConfiguration(iI) = tConfiguration;
    end
end

% If the third and fourth input arguments are set, the user wants to plot
% less data than actually exists. This is usually done to reduce the file
% size of MATLAB figure files that are saved. 
% The plotting interval can be either a number of ticks or a time interval
% in seconds. Which is used is determined by the sIntervalMode input
% argument.
if nargin > 2
    % First we initialize a boolean array that will be used to delete the
    % data in the arrays that are returned.
    abDeleteData = true(1,iTick);
    
    % Switching through the two possible interval modes
    switch sIntervalMode
        case 'Tick'
            if fIntervalValue > 1
                % On our boolean array we set those items to false that we
                % DON'T want to delete.
                abDeleteData(1:fIntervalValue:iTick) = false;
            else
                % If the interval value is one, we want to keep all values,
                % so we can set the entire array to false.
                abDeleteData = false(1,iTick);
            end
        case 'Time'
            % We initialize a time tracker at zero, the beginning of the
            % simulation.
            fTime = 0;
            
            % Now we loop through all of the ticks and see, if the current
            % time is larger or equal to the next interval.
            for iI = 1:iTick
                if this.afTime(iI) >= fTime
                    % The time stamp in this tick is larger or equal to the
                    % interval, so we set that item in the boolan array to
                    % false, so it is not deleted.
                    abDeleteData(iI) = false;
                    
                    % Now we have to increment the time tracker by our time
                    % interval so the next tick's time stamp is smaller
                    % than the tracker again.
                    fTime = fTime + fIntervalValue;
                end
            end
            
        otherwise
            % If the user provided an unknown interval mode string, we let
            % him or her know.
            this.throw('get','The plotting interval mode you have provided (%s) is unknown. Can either be ''Tick'' or ''Time''.', sIntervalMode);
    end
    
    % Using our abDeleteData boolean array we can now delete all of the
    % unneded data rows in the aafData array.
    mfData(abDeleteData,:) = [];
    
    % We also need to provide an array with the time steps of the selected
    % data rows. we get this by only getting those items that were not
    % deleted from the afTime property of the logger.
    afTime = this.afTime(~abDeleteData);
else
    % No interval is set, so we have to do nothing with mfData and can
    % just use afTime as is.
    afTime = this.afTime;
end
end
