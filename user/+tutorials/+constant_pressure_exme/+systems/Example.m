classdef Example < vsys
    %EXAMPLE Example simulation using special exme processors in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in 
    %   between. In contrast to the simple flow tutorial, we use two
    %   constant pressure exmes here. These shouldn't be used lightly since
    %   they can be a large departure from the real situation. The best use
    %   case would be a valve opening into deep space where the pressure
    %   will not change, even if large amounts of matter flow into it. This
    %   is hard to model since stores and phases in V-HAB have finite
    %   volumes. Here an exme with a constant pressure of 0 Pa makes the
    %   simulation more realistic. 
    %   In the example given here, we use two constant pressure exmes to
    %   create a constant flow rate between two tanks. 
    
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
            
            % Creating a store, volume 1 m^3
            this.addStore(matter.store(this, 'Tank_1', 1));
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1);
            
            % Creating a second store, volume 1 m^3
            this.addStore(matter.store(this, 'Tank_2', 1));
            
            % Adding a phase to the store 'Tank_2', 1 m^3 air
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1);
            
            % Adding the constant pressure exmes to the phase. The last
            % parameter is the constant port pressure.
            special.matter.const_press_exme(oGasPhase, 'Port_1', 101325);
            special.matter.const_press_exme(oAirPhase, 'Port_2',  50662);
             
            % Adding a pipe to connect the tanks
            this.addProcF2F(components.pipe('Pipe', 1.5, 0.005));
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            oBranch = this.createBranch('Tank_1.Port_1', {'Pipe'}, 'Tank_2.Port_2');
            
            % Seal - means no more additions of stores etc can be done to
            % this system.
            this.seal();
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the iterative
            % solver. 
            solver.matter.iterative.branch(oBranch);
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
        end
        
     end
    
end

