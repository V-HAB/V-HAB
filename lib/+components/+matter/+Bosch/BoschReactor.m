classdef BoschReactor < vsys
    %BOSCHREACTOR is a subsystem model of a Series Bosch Reactor
    
    methods
        function this = BoschReactor(oParent, sName)
            
            this@vsys(oParent, sName, 0.1);
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% Compressor/stream mixer
            % Note that the phase in the compressor is the only non flow
            % phase in the bosch reactor, and therefore models the complete
            % reactor volume. This is done to increase simulation speed
            % while maintaining a realistic Series Bosch behavior where the
            % composition in the reactor can change
            fVolume = pi*(0.5/2)^2 * 1;
            matter.store(this, 'Compressor', fVolume);
            
            % Creating one phase for the stream mixer
            oPhaseCompressor = this.toStores.Compressor.createPhase(  'gas', 'CO2_H2_CO_H2O',   fVolume , struct('CO2', 5e4, 'H2', 5e4, 'CO', 5e4, 'H2O', 5e4), 293.15, 0);
            
            % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oPhaseCompressor, 'Inlet_RWGSr'); %Compressor Inlet = RWGS Outlet
            matter.procs.exmes.gas(oPhaseCompressor, 'Inlet_CFR');   %Compressor Inlet = CFR Outlet
            matter.procs.exmes.gas(oPhaseCompressor, 'Outlet'); %Stream Mix 
            
            %% RWGS reactor
            matter.store(this, 'RWGSr', 0.01);
            % Creating one phase for the Reactor
            oPhaseRWGS = this.toStores.RWGSr.createPhase(  'gas', 'flow',   'CO2_H2_CO_H2O',   0.01, struct('CO2', 1e5), 1100, 0);
            
            % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oPhaseRWGS, 'Inlet_H2');
            matter.procs.exmes.gas(oPhaseRWGS, 'Inlet_CO2');
            matter.procs.exmes.gas(oPhaseRWGS, 'Outlet');
            
            % Creating the manipulator
            components.matter.Bosch.components.RWGSr('RWGSr', oPhaseRWGS);
            
            
            %% Water Separation assembly
            % Create a geometry object, here its a cylinder 0.25 m in
            % diameter and 0.3 m high.
            fVolume = pi*(0.25/2)^2 * 0.3;
            
            matter.store(this, 'Condensator', fVolume);
            
            % Creating two phases, one for the flow, one for the filter
            oGasPhaseWSA    = this.toStores.Condensator.createPhase(  'gas',    'flow',   'Condensator',  fVolume * 0.9, struct('CO2', 1e5), 293.15, 0);
            oFilteredPhase  = this.toStores.Condensator.createPhase(  'liquid', 'flow',   'Condensate',   fVolume * 0.1, struct('H2O', 1), 293.15, 1e5);
            
            % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oGasPhaseWSA, 'Inlet');
            matter.procs.exmes.gas(oGasPhaseWSA, 'Outlet');
            
            % Each phase gets one exme for connection to the p2p proc. 
            matter.procs.exmes.gas(oGasPhaseWSA,   'FilterPortGas');
            matter.procs.exmes.liquid(oFilteredPhase, 'FilterPortCondensate');
            matter.procs.exmes.liquid(oFilteredPhase, 'CondensateOutlet');
            
            % Creating the p2p processor.
            % Parameter: name, from, to, substance, capacity
            components.matter.Bosch.components.ExtractionAssembly(this.toStores.Condensator, 'WSAProc', 'Condensator.FilterPortGas', 'Condensate.FilterPortCondensate', 'H2O', 1);
            
            %% Membrane Reactors
            %% CO2 Separation Assembly
             % Create a geometry object, here its a cylinder 0.25 m in
            % diameter and 0.3 m high.
            fVolume = pi*(0.25/2)^2 * 0.3;
            
            matter.store(this, 'MembraneReactorCO2', fVolume);
            
            % Creating two phases, on for the flow, one for the filter
            oFlowPhase      = this.toStores.MembraneReactorCO2.createPhase(  'gas', 'flow',   'Membrane_Reactor1_Input',   fVolume * 0.9, struct('CO2', 1e5), 293.15, 0);
            oFilteredPhase  = this.toStores.MembraneReactorCO2.createPhase(  'gas', 'flow',   'Membrane_Reactor1_Output2', fVolume * 0.1, struct('CO2', 1e5), 293.15, 0);
            
            % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oFlowPhase, 'Inlet');
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            
            % Each phase gets one exme for connection to the p2p proc. 
            matter.procs.exmes.gas(oFlowPhase,     'FilterPortFlow');
            matter.procs.exmes.gas(oFilteredPhase, 'FilterPort');
            matter.procs.exmes.gas(oFilteredPhase, 'CO2_Outlet');
            
            % Creating the p2p processor.
            components.matter.Bosch.components.ExtractionAssembly(this.toStores.MembraneReactorCO2, 'CO2FilterProc', 'Membrane_Reactor1_Input.FilterPortFlow', 'Membrane_Reactor1_Output2.FilterPort', 'CO2', 0.8);
            
            %% H2 Separation Assembly
            % Create a geometry object, here its a cylinder 0.25 m in
            % diameter and 0.3 m high.
            fVolume = pi*(0.25/2)^2 * 0.3;
            
            matter.store(this, 'MembraneReactorH2', fVolume);
            
            % Creating two phases, on for the flow, one for the filter
            oFlowPhase      = this.toStores.MembraneReactorH2.createPhase(  'gas', 'flow',   'Membrane_Reactor2_Input',   fVolume * 0.9, struct('CO2', 1e5), 293.15, 0);
            oFilteredPhase  = this.toStores.MembraneReactorH2.createPhase(  'gas', 'flow',   'Membrane_Reactor2_Output2', fVolume * 0.1, struct('H2', 1e5), 293.15, 0);
            
            % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oFlowPhase, 'Inlet');
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            
            % Each phase gets one exme for connection to the p2p proc. 
            matter.procs.exmes.gas(oFlowPhase,     'FilterPortFlow');
            matter.procs.exmes.gas(oFilteredPhase, 'FilterPort');
            matter.procs.exmes.gas(oFilteredPhase, 'H2_Outlet');
            
            % Creating the p2p processor.
            components.matter.Bosch.components.ExtractionAssembly(this.toStores.MembraneReactorH2, 'H2FilterProc', 'Membrane_Reactor2_Input.FilterPortFlow', 'Membrane_Reactor2_Output2.FilterPort', 'H2', 0.6);
            
            %% Carbon Formation Reactor
            % Create a geometry object, here its a cylinder 0.25 m in
            % diameter and 0.3 m high.
            fVolume = pi*(0.25/2)^2 * 0.3;
            
            matter.store(this, 'CFR', fVolume);
            
           % Creating two phases, on for the flow, one for the filter
           
            oFlowPhase = this.toStores.CFR.createPhase(  'gas', 'flow',   'CO2_H2_CO_H2O',   fVolume * 0.9, struct('CO2', 1e5), 823.15, 0);
            
            oFilteredPhase = this.toStores.CFR.createPhase(	'solid',	'C',    fVolume * 0.1,       struct('C', 1),       823.15, 1e5);
            
            % Create the according exmes
            % In- and Outlet for the flow phase
            matter.procs.exmes.gas(oFlowPhase, 'Inlet');
            matter.procs.exmes.gas(oFlowPhase, 'Outlet');
            
            % Each phase gets one exme for connection to the p2p proc. 
            matter.procs.exmes.gas(oFlowPhase,     'FilterPortFlow');
            matter.procs.exmes.solid(oFilteredPhase, 'FilterPort');
            matter.procs.exmes.solid(oFilteredPhase, 'Carbon_Outlet');
            
            % Creating the manipulator
            components.matter.Bosch.components.CarbonFormation('CFR', oFlowPhase);
            
            % Creating the p2p processor.
            components.matter.Bosch.components.ExtractionAssembly(this.toStores.CFR, 'CFRFilterProc', 'CO2_H2_CO_H2O.FilterPortFlow', 'C.FilterPort', 'C', 1);
            
            %% Adding the Fan store
            matter.store(this, 'PostFan', fVolume);
            oFlowPhase = this.toStores.PostFan.createPhase(  'gas',   'PostFan',   fVolume, struct('CO2', 1e5), 293.15, 0);
            
            %% Pipes for connection
            fPipelength         = 0.15;
            fPipeDiameter       = 0.02;
            fFrictionFactor     = 2e-4;
            components.matter.pipe(this, 'Pipe_H2Tank_RWGSr',               fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_CO2Tank_RWGSr',              fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_RWGSr_Compressor',           fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_Compressor_WSA',             fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_WSA_CO2Extractor',           fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_CO2Extractor_H2Extractor',   fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_H2Extractor_CFR',            fPipelength, fPipeDiameter, fFrictionFactor);
            components.matter.pipe(this, 'Pipe_CFR_Compressor',             fPipelength, fPipeDiameter, fFrictionFactor);
            
            components.matter.checkvalve(this, 'Checkvalve');
%             components.matter.fan_simple(this, 'Fan', 2e5);
            
            %valve for CO2Store-RWGSr in case that no H2 available
            %this.addProcF2F(components.valve(this.oData.oMT, 'Valve_CO2Tank_RWGSr', true, 0.05));
            %valve for H2Store-RWGSr in case that no H2 available
            %this.addProcF2F(components.valve(this.oData.oMT, 'Valve_H2Tank_RWGSr',  true, 0.05));
            
            %Flowpaths between all components
            %adding branches
            matter.branch(this, 'RWGSr.Inlet_H2',               {'Pipe_H2Tank_RWGSr'},              'H2_Inlet',                 'H2_Inlet');
            matter.branch(this, 'RWGSr.Inlet_CO2',              {'Pipe_CO2Tank_RWGSr'},             'CO2_Inlet',                'CO2_Inlet');
            
            matter.branch(this, 'RWGSr.Outlet',                 {'Pipe_RWGSr_Compressor'},          'Compressor.Inlet_RWGSr',   'RWGS_Compressor');
            matter.branch(this, 'Compressor.Outlet',            {'Pipe_Compressor_WSA'},           	'Condensator.Inlet',        'Compressor_Condensator');
            matter.branch(this, 'Condensator.Outlet',       	{'Pipe_WSA_CO2Extractor'},          'MembraneReactorCO2.Inlet', 'Condensator_Membrane_CO2');
            matter.branch(this, 'MembraneReactorCO2.Outlet', 	{'Pipe_CO2Extractor_H2Extractor'},  'MembraneReactorH2.Inlet',  'Condensator_Membrane_H2');
            matter.branch(this, 'MembraneReactorH2.Outlet', 	{'Pipe_H2Extractor_CFR'},           'CFR.Inlet',                'Membrane_CFR');
            matter.branch(this, 'CFR.Outlet',                   {'Pipe_CFR_Compressor', 'Checkvalve'},            oFlowPhase,                 'CFR_Fan');
            matter.branch(this, oFlowPhase,                     {},                                 'Compressor.Inlet_CFR',     'Fan_Compressor');
            
            
            matter.branch(this, 'Condensator.CondensateOutlet', {},                                 'Condensate_Outlet',        'Condensate_Outlet');
            matter.branch(this, 'MembraneReactorCO2.CO2_Outlet',{},                                 'CO2_Outlet',               'CO2_Outlet');
            matter.branch(this, 'MembraneReactorH2.H2_Outlet',  {},                                 'H2_Outlet',                'H2_Outlet');
            matter.branch(this, 'CFR.Carbon_Outlet',            {},                                 'C_Outlet',                 'C_Outlet');
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            % Adding heat sources to keep reactor temperatures at the
            % desired temperature levels. A model improvement would add the
            % reaction enthalpies to the calculations which is currently
            % neglected
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Compressor_Constant_Temperature');
            this.toStores.Compressor.toPhases.CO2_H2_CO_H2O.oCapacity.addHeatSource(oHeatSource);
            oHeatSource = components.thermal.heatsources.ConstantTemperature('CFR_Constant_Temperature');
            this.toStores.CFR.toPhases.CO2_H2_CO_H2O.oCapacity.addHeatSource(oHeatSource);
            oHeatSource = components.thermal.heatsources.ConstantTemperature('RWGS_Constant_Temperature');
            this.toStores.RWGSr.toPhases.CO2_H2_CO_H2O.oCapacity.addHeatSource(oHeatSource);
            oHeatSource = components.thermal.heatsources.ConstantTemperature('Fan_Constant_Temperature');
            this.toStores.PostFan.toPhases.PostFan.oCapacity.addHeatSource(oHeatSource);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.CO2_Inlet);
            solver.matter.manual.branch(this.toBranches.H2_Inlet);
%             solver.matter.manual.branch(this.toBranches.Compressor_Condensator);
            solver.matter.manual.branch(this.toBranches.C_Outlet);
            
            solver.matter.residual.branch(this.toBranches.Fan_Compressor);
            
            
            aoMultiSolverBranches = [
                this.toBranches.RWGS_Compressor,...
                this.toBranches.Compressor_Condensator,...
                this.toBranches.Condensator_Membrane_CO2,...
                this.toBranches.Condensator_Membrane_H2,...
                this.toBranches.Membrane_CFR,...
                this.toBranches.CFR_Fan,...
                this.toBranches.Condensate_Outlet,...
                this.toBranches.CO2_Outlet,...
                this.toBranches.H2_Outlet,...
                ];
        
            tSolverProperties.fMaxError = 1e-4;
            tSolverProperties.iMaxIterations = 1000;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;
            tSolverProperties.bSolveOnlyFlowRates = false;
            
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            
            
            this.setThermalSolvers();
        end
        
        function setIfFlows(this, H2_Inlet, CO2_Inlet, Condensate_Outlet, CO2_Outlet, H2_Outlet, C_Outlet)
            if nargin == 7
                this.connectIF('H2_Inlet' ,         H2_Inlet);
                this.connectIF('CO2_Inlet',         CO2_Inlet);
                this.connectIF('Condensate_Outlet',	Condensate_Outlet);
                this.connectIF('CO2_Outlet',        CO2_Outlet);
                this.connectIF('H2_Outlet',         H2_Outlet);
                this.connectIF('C_Outlet',          C_Outlet);
            else
                error('Bosch Reactor Subsystem was given a wrong number of interfaces')
            end
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            
        end
    end
end

