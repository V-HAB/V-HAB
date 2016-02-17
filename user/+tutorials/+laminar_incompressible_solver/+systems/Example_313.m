classdef Example_313 < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 0.5;
        fPipeDiameter = 0.0254/3; 
    end
    
    methods
        function this = Example_313(oParent, sName)
            this@vsys(oParent, sName, 1);
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            matter.store(this, 'Vacuum', 10000);
            this.toStores.Vacuum.createPhase('N2Atmosphere', 0.001);
            matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_1');
            matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_2');
            matter.procs.exmes.gas(this.toStores.Vacuum.aoPhases(1), 'Port_3');
            
            
            
            matter.store(this, 'Store', 100);
            this.toStores.Store.createPhase('N2Atmosphere', this.toStores.Store.fVolume);
            special.matter.const_press_exme(this.toStores.Store.aoPhases(1), 'Port_Out', 600 + this.toStores.Store.aoPhases(1).fPressure);
            special.matter.const_press_exme(this.toStores.Store.aoPhases(1), 'Port_Rtn', this.toStores.Store.aoPhases(1).fPressure);
            
            
            
            iValves = 2;
            
            tStores = struct(...
                'Splitter', struct('fVolume', 1e-6, 'csExmes', {{ 'Inlet', 'To_BedA' }}), ...
                'Merger',   struct('fVolume', 1e-6, 'csExmes', {{ 'From_BedA', 'Outlet' }}), ...
                'BedA',     struct('fVolume', 1e-3, 'csExmes', {{ 'From_Splitter', 'To_Merger', 'To_Vacuum' }}) ...
            );
            csStores = fieldnames(tStores);
            
            for iT = 1:length(csStores)
                sN = csStores{iT};
                tS = tStores.(sN);
                
                matter.store(this, sN, tS.fVolume);
                cParams = matter.helper.phase.create.N2Atmosphere(this, this.toStores.(sN).fVolume);
                matter.phases.gas_pressure_manual(this.toStores.(sN), 'flow', cParams{:});
                
                for iE = 1:length(tS.csExmes)
                    matter.procs.exmes.gas(this.toStores.(sN).aoPhases(1), tS.csExmes{iE});
                end
            
            end
            
            cParams = matter.helper.phase.create.N2Atmosphere(this, this.toStores.BedA.fVolume);
            matter.phases.gas_pressure_manual(this.toStores.BedA, 'adsorbed', cParams{:});
            
            matter.procs.exmes.gas(this.toStores.BedA.aoPhases(2), 'To_Vacuum_Ads');
            
            
            % Add p2p between BedA flow and adsorbed
            %TODO tutorial dummy p2p to components library wiht
            %     fCharacteristics! Also return COeffs Function!
            components.generic.filter(this.toStores.BedA, 'co2_filter', 'flow', 'adsorbed', 'CO2', 3);
            
            
            
            
            % Pipes Loop
            components.pipe(this, 'Pipe_Atmos_Splitter',  this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Splitter_BedA_1', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Splitter_BedA_2', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_BedA_Merger_1',   this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_BedA_Merger_2',   this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_Merger_Atmos',    this.fPipeLength, this.fPipeDiameter);
            
            components.valve_closable(this, 'Valve_Splitter_BedA');
            components.valve_closable(this, 'Valve_BedA_Merger');
            
            
            % To Vacuum Comps
            components.pipe(this, 'Pipe__BedA_Flow__Vacuum__1',     this.fPipeLength, this.fPipeDiameter / 10);
            components.pipe(this, 'Pipe__BedA_Flow__Vacuum__2',     this.fPipeLength, this.fPipeDiameter / 10);
            components.pipe(this, 'Pipe__BedA_Adsorbed__Vacuum__1', this.fPipeLength, this.fPipeDiameter / 10);
            components.pipe(this, 'Pipe__BedA_Adsorbed__Vacuum__2', this.fPipeLength, this.fPipeDiameter / 10);
            
            components.valve_closable(this, 'Valve__BedA_Flow__Vacuum').setOpen(false);
            components.valve_closable(this, 'Valve__BedA_Adsorbed__Vacuum').setOpen(false);
            
            
            
            
            matter.branch(this, 'Store.Port_Out', { 'Pipe_Atmos_Splitter' }, 'Splitter.Inlet');
            
            matter.branch(this, 'Splitter.To_BedA', { 'Pipe_Splitter_BedA_1', 'Valve_Splitter_BedA', 'Pipe_Splitter_BedA_2' }, 'BedA.From_Splitter');
            matter.branch(this, 'BedA.To_Merger',   { 'Pipe_BedA_Merger_1', 'Valve_BedA_Merger', 'Pipe_BedA_Merger_2' },       'Merger.From_BedA');
            
            matter.branch(this, 'Merger.Outlet', { 'Pipe_Merger_Atmos' }, 'Store.Port_Rtn');
            
            
            
            
            matter.branch(this, 'BedA.To_Vacuum',     { 'Pipe__BedA_Flow__Vacuum__1', 'Valve__BedA_Flow__Vacuum', 'Pipe__BedA_Flow__Vacuum__2' }, 'Vauum.Port_1');
            matter.branch(this, 'BedA.To_Vacuum_Ads', { 'Pipe__BedA_Adsorbed__Vacuum__1', 'Valve__BedA_Adsorbed__Vacuum', 'Pipe__BedA_Adsorbed__Vacuum__2' }, 'Vauum.Port_2');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Set CPE pressures from phase
            fPressure = this.toStores.Store.aoPhases(1).fPressure;
            
            this.toStores.Store.aoPhases(1).coProcsEXME{1}.fPortPressure = fPressure + 600;
            this.toStores.Store.aoPhases(1).coProcsEXME{2}.fPortPressure = fPressure;
            
            
            solver.matter_multibranch.laminar_incompressible.branch(this.aoBranches);
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            
            % LOGIC:
            % close valves airloop, open to vacuum; reverse;
            % open valve splitter - bed, and vacuum valve bedA flow!
            % ... hmmm. Update because of rMaxChange, right?
            %
            % ALL TO VAC -> vac flow is BC for multi solver. However,
            % updates BEFORE multi solver, if phase update in BEdA.
            % However, no phase update in BedA, as SUM(FRs) = zero! So
            % update because of iterative solver -> flow bedA massupd ->
            % synced -> multi solver update. yay! Also of course because BC
            % pressure drops -> update. works!
            %
            % -> airloop valves closed -> no SUM(FR) = 0
            % -> 
        end
        
     end
    
end

