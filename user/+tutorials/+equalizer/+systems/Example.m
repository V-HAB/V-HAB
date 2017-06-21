classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1.5;
        fPipeDiameter = 0.005;
        
        % Pressure difference in bar
        fPressureDifference = 1;
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
            
            % Make the system configurable
%             disp(this);
%             disp('------------');
%             disp(this.oRoot.oCfgParams.configCode(this));
%             disp('------------');
%             disp(this.oRoot.oCfgParams.get(this));
%             disp('------------');
            eval(this.oRoot.oCfgParams.configCode(this));
            
            %disp(this);
            
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 10);
            
            % in order to create a gas phase several options exist. You can
            % define the tfMass struct containing the substances as fields
            % and their mass as field values:
            % tfMass = struct('N2', 10, 'O2', 2, 'CO2', 1);
            % matter.phases.gas(this.toStores.Tank_1, 'gas', tfMass, 10, 293);
            % This example would create a gas phase with a volume of 10 and 293 K Temperature
            % using the tfMass struct to define the masses in the phase to
            % be 10 kg of N2 , 2 kg of O2 and 1 kg of CO2
            
            % Since most of the time you will probably want to define not
            % the masses of the gases but their partial pressure you can
            % use a helper to calculate the tfMass struct for you. Just
            % define a similar struct that contains not the masses of the
            % substances but their partial pressures:
            tfPartialPressure = struct('N2', 8e4, 'O2', 2e4, 'CO2', 500);
            % and then use the helper together with desired volume and
            % temperature of the gas phase
            %                   (Object that has oMT as property, Volume, Pressure Struct, Temperature , Relative Humidity)
            tfMasses = matter.helper.phase.create.gas(this,           10, tfPartialPressure,      293,        0.5);
            % The relative humidity is only an optional input, you can also
            % define the partial pressure of the gas. However if a humidity
            % is specified it will take precedence over any pressure for
            % water that is defined
            
            %Adding a phase to the store 'Tank_1', 1 m^3 air at 20 deg C:
            %                              Store for the Phase,   Name for the phase, Mass struct, Volume, Temperature
            oGasPhase = matter.phases.gas(this.toStores.Tank_1,     'gas',              tfMasses,   10,     293);
            
            % There are also other helpers that you can use for example to
            % define air. Just go to the core/matter/helper/phase/create
            % folder to find all the helpers that currently exist!
            
            % You can also use the helpers directly to generate the phase
            % in the store, but in that case you will not be able to define
            % the name of the phase yourself:
            % oGasPhase = this.toStores.Tank_1.createPhase('air', 1, 293.15);
            % oGasPhase = this.toStores.Tank_1.createPhase('gas', 10, tfPartialPressure, 293, 0.5);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 10);
            
            % The custom air helper uses mass ratios to define air, for all
            % substances that are not defined in the trMasses struct it
            % uses the standard composition of air
            trMasses = struct('CO2',0.0068);
            cParams = matter.helper.phase.create.air_custom(this, 10, trMasses,      313,        0.5 , 2e5);
            tfMasses = cParams{1};
            % Adding a phase to the store 'Tank_2', 10 m^3 air at 50 deg C
            oAirPhase = matter.phases.gas(this.toStores.Tank_2, 'gas', tfMasses, 10, 323);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
             
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter.
            components.pipe(this, 'Pipe', this.fPipeLength, this.fPipeDiameter);
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe'}, 'Tank_2.Port_2');
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. 
            
            % first parameter after tha branch is the maximum flowrate, the
            % second parameter is the maximum pressure difference. The
            % equalizer uses these to calculate the flowrate based on the
            % current actual pressure difference
            solver.matter.equalizer.branch(this.aoBranches(1), 0.1, 3e5);
             
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

