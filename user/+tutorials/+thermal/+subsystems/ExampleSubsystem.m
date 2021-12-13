classdef ExampleSubsystem < vsys
    %EXAMPLESUBSYSTEM A subsystem containing a filter and a pipe
    %   This example shows a vsys child representing a subsystem of a 
    %   larger system. It has a filter which removes H2O and CO2 and also
    %   provides thermal interfaces to the parent system
    
    properties
    end
    
    methods
        function this = ExampleSubsystem(oParent, sName)
            
            this@vsys(oParent, sName);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            fFilterVolume = 1;
            matter.store(this, 'Filter', fFilterVolume);
            oFiltered = matter.phases.mixture(this.toStores.Filter, 'FilteredPhase', 'solid', struct('Zeolite13x', 1), 293, 1e5);
            
            oFlow = this.toStores.Filter.createPhase('gas', 'FlowPhase', fFilterVolume - oFiltered.fVolume, struct('N2', 8e4, 'O2', 2e4, 'CO2', 500), 293, 0.5);
            
            tutorials.p2p.stationary.components.AbsorberExample(this.toStores.Filter, 'filterproc', oFlow, oFiltered);
            
            matter.branch(this, oFlow, {}, 'Inlet',  'Inlet');
            matter.branch(this, oFlow, {}, 'Outlet', 'Outlet');
            
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oCapacityFlow     = this.toStores.Filter.toPhases.FlowPhase.oCapacity;
            oCapacityFiltered = this.toStores.Filter.toPhases.FilteredPhase.oCapacity;
            
            % just like for the matter domain, we can also define
            % conductors in both parts of interfaces branches, in the
            % parent system and in the subsystem
            fWallThickness = 0.002; % 2mm of wall thickness for the pipe
            fPipeDiameter = 0.0005;
            fPipeMaterialArea = (pi*(fPipeDiameter + fWallThickness)^2) - (pi*fPipeDiameter^2);
            fPipeLength = 0.5;
            
            fThermalConductivityCopper = 15;
            
            fMaterialConductivity = (fPipeMaterialArea * fThermalConductivityCopper)/fPipeLength;
            
            thermal.procs.conductors.conductive(this, 'Material_Conductor1', fMaterialConductivity);
            thermal.procs.conductors.conductive(this, 'Material_Conductor2', fMaterialConductivity);
            
            thermal.branch(this, oCapacityFlow, {'Material_Conductor1'}, 'Inlet_Conduction',  'Pipe_Material_Conductor_In');
            thermal.branch(this, oCapacityFlow, {'Material_Conductor2'}, 'Outlet_Conduction', 'Pipe_Material_Conductor_Out');
            
            % Here we also add a convective conductor to model the
            % interaction between the gas and the solid phase in the filter
            fLength     = 1;
            fBroadness  = 0.1;
            fFlowArea   = fBroadness * 0.1;
            tutorials.thermal.components.convection_Filter(this, 'Convective_Conductor', fLength, fBroadness, fFlowArea, this.toBranches.Inlet, 1);
            
            thermal.branch(this, oCapacityFlow, {'Convective_Conductor'}, oCapacityFiltered, 'Convective_Branch');
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.interval.branch(this.aoBranches(1));
            solver.matter.interval.branch(this.aoBranches(2));
            
            this.setThermalSolvers();
        end
        
        function setIfFlows(this, sInlet, sOutlet)
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
        end
        
        function setIfThermal(this, sInlet, sOutlet)
            % The setIfThermal function is completly analog to the
            % setIfFlows of the matter domain. View the subsystem tutorial
            % for more information on the setIfFlows function. The only
            % difference is, that connectThermalIF is used instead of
            % connectIF.
            this.connectThermalIF('Inlet_Conduction',  sInlet);
            this.connectThermalIF('Outlet_Conduction', sOutlet);
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
        end
     end
end