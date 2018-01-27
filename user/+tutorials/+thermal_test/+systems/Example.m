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
            this@vsys(oParent, sName, 1);
            
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
            
            % Atmos - Capacity
            fVolume = 1e10;
            matter.store(this, 'Space', 1e10);
            
            tfPartialPressure   = struct('N2', 5);
            fTemperature        = 3;
            rRelativeHumidity   = 0;
            this.toStores.Space.createPhase('gas', 'vacuum',  fVolume, tfPartialPressure, fTemperature, rRelativeHumidity);
            
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air at 20 deg C
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1, 293.15);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air at 50 deg C
            oAirPhase = this.toStores.Tank_2.createPhase('air', this.fPressureDifference + 1, 323.15);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
             
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter.
            components.pipe(this, 'Pipe', this.fPipeLength, this.fPipeDiameter);
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe'}, 'Tank_2.Port_2', 'Branch');
            
        end
        
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
%             oCapa = this.addCreateCapacity(this.toStores.Atmos.toPhases.hell);
%             oProc = this.toProcsF2F.Pipe;
%             fArea = oProc.fLength * pi * (oProc.fDiameter / 2)^2;
            
            oCapacityTank_1 = this.toStores.Tank_1.aoPhases(1).oCapacity;
            oHeatSource = thermal.heatsource('Heater', 0);
            oCapacityTank_1.addHeatSource(oHeatSource);
            
            oCapacitySpace = this.toStores.Space.toPhases.vacuum.oCapacity;
            oCapacityTank_2 = this.toStores.Tank_2.aoPhases(1).oCapacity;
            
            thermal.procs.exme(oCapacitySpace, 'Radiator_1');
            thermal.procs.exme(oCapacityTank_2, 'Radiator_2');
            
            thermal.procs.exme(oCapacityTank_1, 'Conductor_1');
            thermal.procs.exme(oCapacityTank_2, 'Conductor_2');
            
            fEpsilon        = 0.8;
            fSightFactor    = 1;
            fArea           = 0.1;
            fRadiativeConductivity = fEpsilon * fSightFactor * this.oMT.Const.fStefanBoltzmann * fArea;
            
            thermal.procs.conductors.radiative(this, 'Radiator_Conductor', fRadiativeConductivity);
            
            
            fWallThickness = 0.002; % 2mm of wall thickness for the pipe
            fPipeMaterialArea = (pi*(this.fPipeDiameter + fWallThickness)^2) - (pi*this.fPipeDiameter^2);
            
%             afMass = zeros(1,this.oMT.iSubstances);
%             afMass(this.oMT.tiN2I.Cu) = 1; % actual mass for this calculation irrelevant
%             afPP = ones(1,this.oMT.iSubstances) * 1e5;
%             fThermalConductivityCopper = this.oMT.calculateThermalConductivity('solid', afMass, 293, afPP);
            
            fThermalConductivityCopper = 15;
            
            fMaterialConductivity = (fPipeMaterialArea * fThermalConductivityCopper)/this.fPipeLength;
            
            thermal.procs.conductors.conduction(this, 'Material_Conductor', fMaterialConductivity);
            
            thermal.branch(this, 'Space.Radiator_1', {'Radiator_Conductor'}, 'Tank_2.Radiator_2', 'Radiator');
            thermal.branch(this, 'Tank_1.Conductor_1', {'Material_Conductor'}, 'Tank_2.Conductor_2', 'Pipe_Material_Conductor');
            
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the iterative
            % solver. 
            oIt1 = solver.matter.iterative.branch(this.aoBranches(1));
            
            solver.thermal.basic_fluidic.branch(this.aoThermalBranches(1), this.aoBranches(1));
            
            solver.thermal.basic.branch(this.toThermalBranches.Radiator);
            solver.thermal.basic.branch(this.toThermalBranches.Pipe_Material_Conductor);
            
            tTimeStepProperties.rMaxChange = 0.001;
            this.toStores.Tank_1.aoPhases(1).oCapacity.setTimeStepProperties(tTimeStepProperties);
            %oIt1.iDampFR = 5;
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            fHeatFlow = 100 * sin(this.oTimer.fTime/10);
            this.toStores.Tank_1.toPhases.Tank_1_Phase_1.oCapacity.toHeatSources.Heater.setHeatFlow(fHeatFlow)
            
            if ~base.oLog.bOff, this.out(2, 1, 'exec', 'Exec vsys %s', { this.sName }); end;
        end
        
     end
    
end

