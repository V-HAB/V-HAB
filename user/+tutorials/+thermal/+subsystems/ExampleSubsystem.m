classdef ExampleSubsystem < vsys
    %EXAMPLESUBSYSTEM A subsystem containing a filter and a pipe
    %   This example shows a vsys child representing a subsystem of a 
    %   larger system. It has a filter which removes O2 from the mass flow 
    %   through the subsystem and it provides the neccessary setIfFlows 
    %   function so the subsystem branches can be connected to the system 
    %   level branches.
    
    properties
    end
    
    methods
        function this = ExampleSubsystem(oParent, sName)
            
            this@vsys(oParent, sName);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a filter as shown in the p2p Example
            tutorials.thermal.components.Filter(this, 'Filter', 10);
            
            % Creating the branch from the parent system into this subsystem
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'Interface port name'
            matter.branch(this, 'Filter.FilterIn', {}, 'Inlet', 'Inlet');
            
            % Creating the branch out of this subsystem into the parent system 
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'Interface port name'
            matter.branch(this, 'Filter.FilterOut', {}, 'Outlet', 'Outlet');
            
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oCapacityFlow = this.toStores.Filter.toPhases.FlowPhase.oCapacity;
            oCapacityFiltered = this.toStores.Filter.toPhases.FilteredPhase.oCapacity;
            
            thermal.procs.exme(oCapacityFlow, 'Inlet_1');
            thermal.procs.exme(oCapacityFlow, 'Outlet_1');
            
            thermal.procs.exme(oCapacityFlow, 'Convective_Flow');
            thermal.procs.exme(oCapacityFiltered, 'Convective_Filtered');
            
            fWallThickness = 0.002; % 2mm of wall thickness for the pipe
            fPipeDiameter = 0.0005;
            fPipeMaterialArea = (pi*(fPipeDiameter + fWallThickness)^2) - (pi*fPipeDiameter^2);
            fPipeLength = 0.5;
            
            fThermalConductivityCopper = 15;
            
            fMaterialConductivity = (fPipeMaterialArea * fThermalConductivityCopper)/fPipeLength;
            
            thermal.procs.conductors.conductive(this, 'Material_Conductor1', fMaterialConductivity);
            thermal.procs.conductors.conductive(this, 'Material_Conductor2', fMaterialConductivity);
            
            thermal.branch(this, 'Filter.Inlet_1', {'Material_Conductor1'}, 'Inlet_Conduction', 'Pipe_Material_Conductor_In');
            thermal.branch(this, 'Filter.Outlet_1', {'Material_Conductor2'}, 'Outlet_Conduction', 'Pipe_Material_Conductor_Out');
            
            fLength     = 1;
            fBroadness  = 0.1;
            fFlowArea   = fBroadness * 0.1;
            tutorials.thermal.components.convection_Filter(this, 'Convective_Conductor', fLength, fBroadness, fFlowArea, this.toBranches.Inlet, 1);
            
            thermal.branch(this, 'Filter.Convective_Flow', {'Convective_Conductor'}, 'Filter.Convective_Filtered', 'Convective_Branch');
            
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Create the solver instances. Generally, this can be done here
            % or directly within the vsys (after the .seal() command).
            oManual = solver.matter.manual.branch(this.aoBranches(1));
            oManual.setFlowRate(-0.1);
            
            solver.matter.residual.branch(this.aoBranches(2));
            %, this.toBranches.(this.aoThermalBranches(1).sName
            solver.thermal.basic_fluidic.branch(this.toThermalBranches.Inlet);
            solver.thermal.basic_fluidic.branch(this.toThermalBranches.Outlet);
            
            solver.thermal.basic.branch(this.toThermalBranches.Pipe_Material_Conductor_In);
            solver.thermal.basic.branch(this.toThermalBranches.Pipe_Material_Conductor_Out);
            solver.thermal.basic.branch(this.toThermalBranches.Convective_Branch);
            
            % Phases
            
            oFilterFlowPhase = this.toStores.Filter.aoPhases(1);
            oFilterBedPhase  = this.toStores.Filter.aoPhases(2);
            
            % We are not really interested in the pressure, heat capacity
            % etc. of the filtered phase, so we don't need to re-calculate
            % it often. So we set a large maximum change. 
            tTimeStepProperties.rMaxChange = 0.5;
            oFilterBedPhase.setTimeStepProperties(tTimeStepProperties);
            
            tTimeStepProperties.rMaxChange = 0.0001;
            oFilterFlowPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();

        end
        
        function setIfFlows(this, sInlet, sOutlet)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
        end
        
        function setIfThermal(this, sInlet, sOutlet)
            
            this.connectThermalIF('Inlet_Conduction',  sInlet);
            this.connectThermalIF('Outlet_Conduction', sOutlet);
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

