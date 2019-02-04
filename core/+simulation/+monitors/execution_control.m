classdef execution_control < simulation.monitor
    %EXECUTION_CONTROL this class controlls the execution of the V-HAB
    % simulation and allows the user to stop a simulation by creating a
    % STOP.m file in the V-HAB directory.
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        iTickInterval = 100;
    end
    
    properties (SetAccess = private, GetAccess = public)
        bPaused = false;
    end
    
    methods
        function this = execution_control(oSimulationInfrastructure)
            this@simulation.monitor(oSimulationInfrastructure, { 'step_post', 'init_post' });
            
        end
    end
    
    
    methods (Access = protected)
        
        function onStepPost(this, ~)
            oInfra = this.oSimulationInfrastructure;
            oSim   = oInfra.oSimulationContainer;
            
            if mod(oSim.oTimer.iTick, this.iTickInterval) == 0
                bPauseGeneral  = (exist([ pwd, filesep, 'STOP' ], 'file') == 2);
                sSpecificFile  = [ 'STOP_' oInfra.sUUID ];
                bPauseSpecific = exist(sSpecificFile, 'file') == 2;
                
                if bPauseSpecific
                    movefile(sSpecificFile, [ sSpecificFile '_OFF' ]);
                end
                
                
                if bPauseGeneral || bPauseSpecific
                    if oSim.oTimer.iTick == 0
                        this.throw('onStepPost','You still have your STOP file in the main directory. Please remove it and restart the simulation.');
                    else
                        oInfra.pause();
                    end
                    
                    this.bPaused = true;
                    
                else
                    this.bPaused = false;
                end
            end
        end
        
        
        function onInitPost(this, ~)
            oInfra = this.oSimulationInfrastructure;
            
            fprintf('[SimController] Pause the simulation by creating a file called "STOP" or "STOP_%s" in the working directory (checked every %ith tick).\n', oInfra.sUUID, this.iTickInterval);
        end
        
    end
end

