classdef executionControl < simulation.monitor
    %EXECUTIONCONTROL Controls the execution of a V-HAB simulation
    % Allows the user to pause a simulation by creating a STOP.m file in
    % the V-HAB directory. In case there are multiple simulations running
    % in parallel, the user has the option to either pause them all with
    % the general STOP.m file or pause only a specific one by creating a
    % file that has the simulation's UUID in the file name (i.e.
    % STOP_<UUID>.m). When a simulation is started, this monitor outputs
    % that file name to the console for convenience. 
    
    properties (SetAccess = protected, GetAccess = public)
        % Interval at which this monitor checks for the existence of a
        % STOP.m file in the base directory
        iTickInterval = 100;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Internal variable indicating if this simulation is paused. This
        % can be used by other classes to make decisions based on the
        % status of the simulation. 
        bPaused = false;
    end
    
    methods
        function this = executionControl(oSimulationInfrastructure)
            % Calling the parent class constructor
            this@simulation.monitor(oSimulationInfrastructure, { 'step_post', 'init_post' });
        end
    end
    
    
    methods (Access = protected)
        
        function onStepPost(this, ~)
            % Setting some local variables to make the code more legible
            oInfra = this.oSimulationInfrastructure;
            oSim   = oInfra.oSimulationContainer;
            
            % Check if we are at a tick where we should look for the file
            if mod(oSim.oTimer.iTick, this.iTickInterval) == 0
                % We are, so we first look for the general stop file.
                bPauseGeneral  = (exist([ pwd, filesep, 'STOP' ], 'file') == 2);
                
                % Now we look for the specific stop file
                sSpecificFile  = [ pwd, filesep, 'STOP_', oInfra.sUUID ];
                bPauseSpecific = exist(sSpecificFile, 'file') == 2;
                
                % If there is a specific stop file, we re-name it so we can
                % get going quickly again without having to re-name it by
                % hand in the file system.
                if bPauseSpecific
                    movefile([sSpecificFile, '.m'], [ sSpecificFile '_OFF.m' ]);
                end
                
                % If either of the stop files is present we need to do
                % something.
                if bPauseGeneral || bPauseSpecific
                    % As will undoubtedly happen, a user may have forgotten
                    % to remove the STOP file when starting a new
                    % simulation run. Here we catch that and let the user
                    % know. Otherwise, we pause!
                    if oSim.oTimer.iTick == 0
                        this.throw('onStepPost','You still have your STOP file in the main directory. Please remove it and restart the simulation.');
                    else
                        oInfra.pause();
                    end
                    
                    % Setting the bPaused property
                    this.bPaused = true;
                    
                else
                    % We are not paused, so we set the bPaused property to
                    % false.
                    this.bPaused = false;
                end
            end
        end
        
        
        function onInitPost(this, ~)
            % After the initialization of the simulation is complete, we
            % have the UUID for the simulation container, so we let the
            % user know that he or she has the option to pause the
            % simulation using the general and specific stop files. 
            fprintf(['[SimController] You can pause the simulation "%s" \n', ...
                     '                by creating a file called "STOP" or \n', ...
                     '                "STOP_%s" in the working directory.\n', ...
                     '                This is checked every %ith tick.\n'], this.oSimulationInfrastructure.sName, this.oSimulationInfrastructure.sUUID, this.iTickInterval);
        end
        
    end
end

