classdef Example_313 < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1;
        fPipeDiameter = 0.0254/3; 
        
        fValveFlowCoeff = 0.5;
        
        toValves = struct();
    end
    
    methods
        function this = Example_313(oParent, sName)
            this@vsys(oParent, sName, 1000);
            
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            
            %%%matter.store(this, 'Vacuum', 10000);
            %%%this.toStores.Vacuum.createPhase('N2Atmosphere', 1);
            %%%special.matter.const_press_exme(this.toStores.Vacuum.aoPhases(1), 'From_Beds', 0.1);
            %special.matter.const_press_exme(this.toStores.Vacuum.aoPhases(1), 'From_BedB', 0);
            
            
            
            matter.store(this, 'Atmosphere', 10);
            this.toStores.Atmosphere.createPhase('N2Atmosphere', this.toStores.Atmosphere.fVolume);
            matter.procs.exmes.gas(this.toStores.Atmosphere.aoPhases(1), 'Out');
            matter.procs.exmes.gas(this.toStores.Atmosphere.aoPhases(1), 'Rtn');
            
            
            
            %iValves = 2;
            
            tStores = struct(...
                'Splitter', struct('fVolume', 1e-6, 'csExmes', {{ 'FromAtmos' }}), ... %, 'BedA', 'BedB' }}), ...
                'Merger',   struct('fVolume', 1e-6, 'csExmes', {{ 'ToAtmos' }}) ... %'BedA', 'BedB', 'ToAtmos' }}) ...
                ... %%%'VacMerge', struct('fVolume', 1e-6, 'csExmes', {{ 'BedA', 'BedB', 'ToVac' }}) ...
                ...
                ...'BedA',     struct('fVolume', 1e-3, 'csExmes', {{ 'From_Splitter', 'To_Merger', 'To_Vacuum' }}) ...
            );
            csStores = fieldnames(tStores);
            
            for iT = 1:length(csStores)
                sN = csStores{iT};
                tS = tStores.(sN);
                
                matter.store(this, sN, tS.fVolume);
                cParams = matter.helper.phase.create.N2Atmosphere(this, this.toStores.(sN).fVolume);
                matter.phases.flow.gas(this.toStores.(sN), 'flow', cParams{:});
                
                for iE = 1:length(tS.csExmes)
                    matter.procs.exmes.gas(this.toStores.(sN).aoPhases(1), tS.csExmes{iE});
                end
            
            end
            
            %cParams = matter.helper.phase.create.N2Atmosphere(this, this.toStores.BedA.fVolume);
            %matter.phases.flow.gas(this.toStores.BedA, 'adsorbed', cParams{:});
            
            %matter.procs.exmes.gas(this.toStores.BedA.aoPhases(2), 'To_Vacuum_Ads');
            
            
            % Add p2p between BedA flow and adsorbed
            %TODO tutorial dummy p2p to components library wiht
            %     fCharacteristics! Also return COeffs Function!
            %%%components.matter.generic.filter(this.toStores.BedA, 'co2_filter', 'flow', 'adsorbed', 'CO2', 3);
            
            
            
            components.matter.pipe(this, 'Pipe_AtmosToSplitter', this.fPipeLength, this.fPipeDiameter);
            components.matter.pipe(this, 'Pipe_MergerToAtmos',   this.fPipeLength, this.fPipeDiameter);
            %%%components.matter.pipe(this, 'Pipe_MergerToVacuum',  this.fPipeLength, this.fPipeDiameter);
            
            
            components.matter.fan_simple(this, 'Fan', 600, false);
            matter.branch(this, 'Atmosphere.Out', { 'Pipe_AtmosToSplitter', 'Fan'}, 'Splitter.FromAtmos');
            matter.branch(this, 'Merger.ToAtmos', { 'Pipe_MergerToAtmos'   }, 'Atmosphere.Rtn');
            %%%matter.branch(this, 'VacMerge.ToVac', { 'Pipe_MergerToVacuum'  }, 'Vacuum.From_Beds');
            
            
            
            
            % Diam, Length
            fDiameter = 0.075;
            fLength   = 0.35;
            fVolume   = pi * (fDiameter/2)^2 * fLength;
            
            % STABLE FOR THAT:
            %oFilterGeo = geometry.volumes.cube(0.5);
            %   and struct('rUpdateFrequency', 10)
            csBeds     = { 'A' };%, 'B' };
            
            for iBed = 1:length(csBeds)
                sBed = [ 'Bed' csBeds{iBed} ];
                oBed = matter.store(this, sBed, fVolume);
                
                oBed.createPhase('N2Atmosphere', fVolume);
                
                
                %ttBranches = struct(...
                %    'Splitter', struct(), ...
                %    'Merger',   struct(), ...
                %    'VacMerge', struct() ...
                %);
                for iT = 1:length(csStores)
                    sOtherStore = csStores{iT};
                    oOtherPhase = this.toStores.(sOtherStore).toPhases.flow;
                    
                    matter.procs.exmes.gas(oOtherPhase, oBed.sName);
                    matter.procs.exmes.gas(oBed.aoPhases(1), sOtherStore);
                    
                    oPipe  = components.matter.pipe(this, [ 'Pipe_' sBed '_' sOtherStore    ], this.fPipeLength, this.fPipeDiameter);
                    oValve = components.matter.valve_closable(this, [ 'Valve_' sBed '_' sOtherStore ], this.fValveFlowCoeff);
                    
                    if strcmp(sOtherStore, 'Splitter')
                        matter.branch(this, ...
                            [ sOtherStore '.' sBed ], ...
                            { oPipe.sName, oValve.sName }, ...
                            [ sBed '.' sOtherStore ] ...
                        );
                    else
                        matter.branch(this, ...
                            [ sBed '.' sOtherStore ], ...
                            { oPipe.sName, oValve.sName }, ...
                            [ sOtherStore '.' sBed ] ...
                        );
                    end
                    
                    this.toValves.([ sBed '_' sOtherStore ]) = oValve;
                end
                
                
%                 matter.procs.exmes.gas(oBed.aoPhases(1), 'From_Splitter');
%                 matter.procs.exmes.gas(oBed.aoPhases(1), 'To_Merger');
%                 matter.procs.exmes.gas(oBed.aoPhases(1), 'To_Vacuum');
%                 
%                 
%                 components.matter.pipe(this, [ 'Pipe_SplitterTo' sBed     ], this.fPipeLength, this.fPipeDiameter);
%                 components.matter.pipe(this, [ 'Pipe_' sBed 'ToMerger'    ], this.fPipeLength, this.fPipeDiameter);
%                 components.matter.pipe(this, [ 'Pipe_' sBed 'ToMergerVac' ], this.fPipeLength, this.fPipeDiameter);
%                 
%                 
%                 components.matter.valve_closable(this, [ 'Pipe_SplitterTo' sBed     ], 0.5);
%                 components.matter.valve_closable(this, [ 'Pipe_' sBed 'ToMerger'    ], 0.5);
%                 components.matter.valve_closable(this, [ 'Pipe_' sBed 'ToMergerVac' ], 0.5);
            end
            
            
            
            
            
            
            
            return;
            
            % Pipes Loop
            components.matter.pipe(this, 'Pipe_Atmos_Splitter',  this.fPipeLength, this.fPipeDiameter);
            components.matter.pipe(this, 'Pipe_Splitter_BedA_1', this.fPipeLength, this.fPipeDiameter);
            components.matter.pipe(this, 'Pipe_Splitter_BedA_2', this.fPipeLength, this.fPipeDiameter);
            components.matter.pipe(this, 'Pipe_BedA_Merger_1',   this.fPipeLength, this.fPipeDiameter);
            components.matter.pipe(this, 'Pipe_BedA_Merger_2',   this.fPipeLength, this.fPipeDiameter);
            components.matter.pipe(this, 'Pipe_Merger_Atmos',    this.fPipeLength, this.fPipeDiameter);
            
            components.matter.valve_closable(this, 'Valve_Splitter_BedA', 0.5);
            components.matter.valve_closable(this, 'Valve_BedA_Merger', 0.5);
            
            
            % To Vacuum Comps
            components.matter.pipe(this, 'Pipe__BedA_Flow__Vacuum__1',     this.fPipeLength, this.fPipeDiameter / 10);
            components.matter.pipe(this, 'Pipe__BedA_Flow__Vacuum__2',     this.fPipeLength, this.fPipeDiameter / 10);
            components.matter.pipe(this, 'Pipe__BedA_Adsorbed__Vacuum__1', this.fPipeLength, this.fPipeDiameter / 10);
            components.matter.pipe(this, 'Pipe__BedA_Adsorbed__Vacuum__2', this.fPipeLength, this.fPipeDiameter / 10);
            
            components.matter.valve_closable(this, 'Valve__BedA_Flow__Vacuum', 0.5, false);%.setOpen(false);
            components.matter.valve_closable(this, 'Valve__BedA_Adsorbed__Vacuum', 0.5, false);%.setOpen(false);
            
            
            
            
            matter.branch(this, 'Store.Port_Out', { 'Pipe_Atmos_Splitter' }, 'Splitter.Inlet');
            
            matter.branch(this, 'Splitter.To_BedA', { 'Pipe_Splitter_BedA_1', 'Valve_Splitter_BedA', 'Pipe_Splitter_BedA_2' }, 'BedA.From_Splitter');
            matter.branch(this, 'BedA.To_Merger',   { 'Pipe_BedA_Merger_1', 'Valve_BedA_Merger', 'Pipe_BedA_Merger_2' },       'Merger.From_BedA');
            
            matter.branch(this, 'Merger.Outlet', { 'Pipe_Merger_Atmos' }, 'Store.Port_Rtn');
            
            
            
            
            matter.branch(this, 'BedA.To_Vacuum',     { 'Pipe__BedA_Flow__Vacuum__1', 'Valve__BedA_Flow__Vacuum', 'Pipe__BedA_Flow__Vacuum__2' }, 'Vacuum.Port_1');
            matter.branch(this, 'BedA.To_Vacuum_Ads', { 'Pipe__BedA_Adsorbed__Vacuum__1', 'Valve__BedA_Adsorbed__Vacuum', 'Pipe__BedA_Adsorbed__Vacuum__2' }, 'Vacuum.Port_2');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            solver.matter_multibranch.iterative.branch(this.aoBranches);
            
            this.setThermalSolvers();
            
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

