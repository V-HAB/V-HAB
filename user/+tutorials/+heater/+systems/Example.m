classdef Example < vsys
    %EXAMPLE Example simulation for the heat flow functionaliy in V-HAB 2.0 F2F processors
    %   Two tanks filled with gas and a pipe in between. The flow rate is 
    %   set to a constant value via a manual solver branch. A dummy heater 
    %   element is included in the branch. In the exec() method of this
    %   class we change the heater's heat flow property every 100 s.
    
    properties
        oBranch;        % A branch object that we can manipulate while the system is running
        
        oHeater;        % A F2F processor object that injects thermal 
                        % energy into the flow, causing a temperature
                        % change. Can also be negative!
        
        bHeaterOn;      % A Boolean variable indicating if the heater is 
                        % currently switched on. 
        
        fSwitchTime;    % A float variable that is used to set the next 
                        % point in the simulated time, when the heater and
                        % flow rate states are changed
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
            this@vsys(oParent, sName, 20);
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1000 m^3
            matter.store(this, 'Tank_1', 1000);
            
            % Adding a phase to the store 'Tank_1', 1000 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 2000);
            
            % Creating a second store, volume 1000 m^3
            matter.store(this, 'Tank_2', 1000);
            
            % Adding a phase to the store 'Tank_2', 1000 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1000);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
             
            % Adding a pipe to connect the tanks, length 1 m, diameter 0.1 m
            components.pipe(this, 'Pipe', 10, 0.01);
            
            this.oHeater = components.heater(this, 'Heater');
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe','Heater'}, 'Tank_2.Port_2');
            
            % Setting the initial switching time for the heater to 100 s. 
            this.fSwitchTime   = 100;
            
            % Initially, the heater is off. 
            this.oHeater.fPower = 0;
            this.bHeaterOn = false;
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Add branch to manual solver and set the flow rate
            this.oBranch = solver.matter.manual.branch(this.aoBranches(1));
            this.oBranch.setFlowRate(0.2);
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it calls its parent's exec function
            exec@vsys(this);
            
            % Now we check if the simulation time has passed the switch 
            % time, if yes we toggle the heater and increase the switch
            % time by another 100 s. This way we change the heater status
            % every 100 s. 
             
            if this.oTimer.fTime > this.fSwitchTime   % Have 100s passed?
                if this.bHeaterOn                           % Is the heater currently on? 
                    this.bHeaterOn = false;                 % Turining the heater off
                    this.oHeater.fPower = 0;
                    
                else
                    this.bHeaterOn = true;                  % Turining the heater on
                    this.oHeater.fPower = 2000;
                    
                end
                
                this.fSwitchTime = this.fSwitchTime + 100;  % Incrementing the switch time
                
            end
            
        end
        
     end
    
end

