classdef Example < vsys
    %EXAMPLE Example simulation for V-HAB 2.0 including a manipulator
    %   Creates two tanks with 1 and 2  atmospheres of pressure,
    %   respectively. The tanks are connected via two pipes. In between the
    %   pipes, there is a simple model of a Bosch reactor system, removing
    %   CO2 from the air flow and reducing it to C and O2. 
    
    properties
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
            this@vsys(oParent, sName, 30);
            
            % Creating a store - volume 10m3
            this.addStore(matter.store(this.oData.oMT, 'Tank_1', 10));
             
            % Create normal air (standard atmosphere) for 20m3. Will
            % have ~twice the pressure of the standard atmosphere, because 
            %the store is volume is only half as big.
            oAir = this.toStores.Tank_1.createPhase('air', 20);
            
            % Adding an extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'Outlet');
            
            %oAir.bSynced = true;
            
            % Creating a store - right side.
            this.addStore(matter.store(this.oData.oMT, 'Tank_2', 10));
            
            % Create normal air (standard atmosphere) for 10m3. Here the 
            % tank and phase volume are the same, so the pressure will be
            % sea-level. 
            oAir = this.toStores.Tank_2.createPhase('air', 10);
            
            %oAir.bSynced = true;
            
            % Adding an extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'Inlet');
            
            
            % Create the reactor. See the according files, just an example
            % for an implementation - copy to your own directory and change
            % as needed.
            this.addStore(tutorials.manipulator_test.subsystems.Transformer(this.oData.oMT, 'Transformer'));
            
            % Adding pipes to connect the components
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_1', 1.5, 0.005));
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe_2', 1.5, 0.005));
            
            % Creating the flowpath between the components
            this.createBranch('Tank_1.Outlet',  { 'Pipe_1' }, 'Transformer.Inlet');
            this.createBranch('Transformer.Outlet', { 'Pipe_2' }, 'Tank_2.Inlet');
            
            % Seal - systems always have to do that!
            this.seal();
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            % See above - time step of this .exec() method is set above,
            % can be used to update some stuff (e.g. apply external
            % disturbances as closing a valve).

        end
        
     end
    
end

