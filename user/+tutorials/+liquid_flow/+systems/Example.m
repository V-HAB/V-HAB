classdef Example < vsys
    %EXAMPLE Example liquid flow simulation for V-HAB 2.0
    %   Two tanks, connected by two pipes with a pump in between. The flow
    %   rate setpoint for the pump is changed every 100 seconds. 
    
    properties
        % Object reference to the f2f processor representing the water 
        % pump. We need this so we can change the setpoint during the 
        % simulation.
        oPump;       
        
        % Boolean variable indicating if the pump flow rate is set to a 
        % value or zero. At the beginning of the simulation it is active.
        bPumpActive = true; 
        
        % This property is used to store the time step during which the 
        % pump switching was last performed.
        fLastPumpUpdate = 0; 
                    
    end
    
    methods
        function this = Example(oParent, sName)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName, 1);
            
            % Creating a store
            this.addStore(matter.store(this, 'Tank_1', 1));
            
            % Creating a second store
            this.addStore(matter.store(this, 'Tank_2', 1));
            
            % Adding a phase with liquid water to the store
            oLiquidPhase = matter.phases.liquid(this.toStores.Tank_1, ...  Store in which the phase is located
                                                'Liquid_Phase', ...        Phase name
                                                struct('H2O', 1000), ...   Phase contents
                                                1, ...                     Phase volume
                                                293.15, ...                Phase temperature
                                                101325);                 % Phase pressure
            
            % Adding an empty phase to the second store, this represents an
            % empty tank
            oWaterPhase = matter.phases.liquid(this.toStores.Tank_2, ...   Store in which the phase is located
                                                'Water_Phase', ...         Phase name
                                                struct('H2O', 0), ...      Phase contents
                                                0.001, ...                 Phase volume
                                                293.15, ...                Phase temperature
                                                101325);                 % Phase pressure
                                            
            
            
            % Adding extract/merge processors to the phases
            matter.procs.exmes.liquid(oLiquidPhase, 'Port_1');
            matter.procs.exmes.liquid(oWaterPhase, 'Port_2');
            
            % Adding a pump
            % Warning! This is a really dumb pump, a better model is in the
            % making in conjuction with a better liquid solver. 
            this.addProcF2F(components.pump('Pump', 0.267));
            
            % Setting the oPump property so we can access the pump settings
            % later.
            this.oPump = this.toProcsF2F.Pump;
            
            % Adding pipes to connect the components
            this.addProcF2F(components.pipe('Pipe_1', 1, 0.1));
            this.addProcF2F(components.pipe('Pipe_2', 1, 0.1));
            
            % Creating the flowpath between the components
            oBranch = this.createBranch('Tank_1.Port_1', {'Pipe_1', 'Pump', 'Pipe_2'}, 'Tank_2.Port_2');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the linear
            % solver. 
            solver.matter.linear.branch(oBranch);
                        
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            % Switching between flow rate setpoints for the pump every 100
            % seconds
            if this.oData.oTimer.fTime - this.fLastPumpUpdate > 100   % Have 100s passed? 
                if this.bPumpActive                   % Is the flow rate currently high? 
                    this.oPump.changeSetpoint(0);     % Set flow rate setpoint to zero
                    this.bPumpActive = false;         % Change pump indicator to false
                else
                    this.oPump.changeSetpoint(0.267); % Set flow rate setpoint to a value
                    this.bPumpActive = true;          % Change pump indicator to false
                end
                
                % Remember this time step as the one we last updated the
                % pump.
                this.fLastPumpUpdate = this.oData.oTimer.fTime;
            end
        end
        
     end
    
end

