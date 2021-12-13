classdef Example < vsys
    %EXAMPLE Example simulation for a thermal system in V-HAB
    % View the png file of this system for a description. This system is
    % inteded to showcase the combination of matter and thermal domain and
    % the different thermal heat transfer mechanisms (conduction,
    % convection, radiation).
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1.5;
        fPipeDiameter = 0.005;
        
        % Pressure difference in bar
        fPressureDifference = 1;
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 1);
            
            tutorials.thermal.subsystems.ExampleSubsystem(this, 'SubSystem');
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Space', Inf);
            this.toStores.Space.createPhase('vacuum','VacuumPhase');
            
            matter.store(this, 'Tank_1', 1);
            
            oTank1Gas = this.toStores.Tank_1.createPhase('air', 'Tank1Air', 1, 293.15);
            
            matter.store(this, 'Tank_2', 1);
            oTank2Gas = this.toStores.Tank_2.createPhase('air', 'Tank2Air', 1, 323.15, 0.5, (1+this.fPressureDifference)*10^5);
            
            components.matter.pipe(this, 'Pipe', this.fPipeLength, this.fPipeDiameter);
            
            matter.branch(this, oTank1Gas, {'Pipe'}, oTank2Gas, 'Branch');
            
            components.matter.pipe(this, 'Pipe1', 1, 0.005);
            components.matter.pipe(this, 'Pipe2', 1, 0.005);
            
            matter.branch(this, 'SubsystemInput',  {'Pipe1'}, oTank2Gas);
            matter.branch(this, 'SubsystemOutput', {'Pipe2'}, oTank2Gas);
            
            this.toChildren.SubSystem.setIfFlows('SubsystemInput', 'SubsystemOutput');
            
        end
        
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % Getting a local variable for the capacity we will be working
            % on to make the code more legible.
            oCapacityTank_1 = this.toStores.Tank_1.toPhases.Tank1Air.oCapacity;

            % The heat source is a basic thermal component which can either
            % increase the temperature of a capacity (positive heat flow)
            % or decrease it (negative heat flow). It can be defined by
            % first creating a heat source object and then adding that heat
            % source to the desired capacity. Afterwards, the heat source
            % can be accessed from the capacity with
            % oCapacity.toHeatsources.<HeatSourceName>
            oHeatSource = thermal.heatsource('Heater', 0);
            
            % Actually adding the heat source to the capacity object.
            oCapacityTank_1.addHeatSource(oHeatSource);
            
            % Add another heat source to the gas phase in Tank 2. This one
            % with a constant heat flow rate of 50 W
            oCapacityTank_2 = this.toStores.Tank_2.toPhases.Tank2Air.oCapacity;
            oHeatSource = thermal.heatsource('Heater', 50);
            oCapacityTank_2.addHeatSource(oHeatSource);
            
            oCapacitySpace = this.toStores.Space.toPhases.VacuumPhase.oCapacity;
            
            % For the radiative thermal exchange, we calculate the thermal
            % resistance assumed for the radiator:
            fEpsilon             = 0.8;
            fSightFactor    	 = 1;
            fArea                = 0.1;
            fRadiativeResistance = 1 / (fEpsilon * fSightFactor * this.oMT.Const.fStefanBoltzmann * fArea);
            
            thermal.procs.conductors.radiative(this, 'Radiator_Conductor', fRadiativeResistance);
            
            % To model thermal conduction, we first have to calculate the
            % conductive resistance. In this case we model the conductive
            % resistance of the piping along the pipes:
            fWallThickness              = 0.002; % 2mm of wall thickness for the pipe
            fPipeMaterialArea           = (pi*(this.fPipeDiameter + fWallThickness)^2) - (pi*this.fPipeDiameter^2);
            fThermalConductivityCopper  = 15;
            fConductionResistance       = this.fPipeLength / (fPipeMaterialArea * fThermalConductivityCopper);
            
            thermal.procs.conductors.conductive(this, 'Material_Conductor', fConductionResistance);
            thermal.procs.conductors.conductive(this, 'Material_Conductor1', fConductionResistance);
            thermal.procs.conductors.conductive(this, 'Material_Conductor2', fConductionResistance);
            
            % The definition of thermal branches follows the same rules as
            % the definition of matter branches. The interfaces for
            % branches from the subsystem always have the interface on the
            % left side in the parent system. The only difference is, that
            % you connect capacities and not phases and use conductors
            % inside the branches not F2Fs.
            thermal.branch(this, oCapacitySpace,                {'Radiator_Conductor'},  oCapacityTank_2, 'Radiator');
            thermal.branch(this, oCapacityTank_1,               {'Material_Conductor'},  oCapacityTank_2, 'Pipe_Material_Conductor');
            
            thermal.branch(this, 'Conduction_From_Subsystem',   {'Material_Conductor1'}, oCapacityTank_2);
            thermal.branch(this, 'Conduction_To_Subsystem',     {'Material_Conductor2'}, oCapacityTank_2);
            
            % The connection of the subsystem is also analog to the matter
            % domain, you just have to use the setIfThermal function!
            this.toChildren.SubSystem.setIfThermal('Conduction_To_Subsystem', 'Conduction_From_Subsystem');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.interval.branch(this.toBranches.Branch);
            
            tTimeStepProperties.rMaxChange = 0.001;
            this.toStores.Tank_1.aoPhases(1).oCapacity.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            % We use sinus to model a "dynamic" heat release in the phase
            % of tank 1
            fHeatFlow = 100 * sin(this.oTimer.fTime/10);
            this.toStores.Tank_1.toPhases.Tank1Air.oCapacity.toHeatSources.Heater.setHeatFlow(fHeatFlow)
            
        end
     end
end