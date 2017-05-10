classdef Example1 < vsys
    %EXAMPLE1 Example simulation demonstrating P2P processors in V-HAB 2.0
    %   Creates one tank, one with ~two bars of pressure, one completely
    %   empty tank. A filter is created. The tanks are connected to the 
    %   filter with pipes of 50cm length and 5mm diameter.
    %   The filter only filters O2 (oxygen) up to a certain capacity. 
    
    properties
        oB1;
        oB2;
        
        aoFilterPhases;
        oAtmosPhase;
        
        
        bManual = false;
    end
    
    methods
        function this = Example1(oParent, sName)
            this@vsys(oParent, sName, 10);
           
            
            %this.bManual = true;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            % Creating a store, volume 10m^3
            matter.store(this, 'Atmos', 10);
            
            % Creating a phase using the 'air' helper
            oAir = this.toStores.Atmos.createPhase('air', 10);
            
            % Adding a extract/merge processor to the phase
            matter.procs.exmes.gas(oAir, 'Out');
            matter.procs.exmes.gas(oAir, 'In');
            
            % Creating the filter, last parameter is the filter capacity in
            % kg.
            tutorials.p2p.components.Filter(this, 'Filter', 0.5);
            
            % Adding a fan
            components.fan(this, 'Fan', 40000, 'Left2Right');
            
            % Adding pipes to connect the components
            components.pipe(this, 'Pipe_1', 0.5, 0.005);
            components.pipe(this, 'Pipe_2', 0.5, 0.005);
            components.pipe(this, 'Pipe_3', 0.5, 0.005);
            
            % Creating the flowpath (=branch) between the components
            % Since we are using default exme-processors here, the input
            % format can be 'store.phase' instead of 'store.exme'
            %oBranch_1 = this.createBranch('Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            %oBranch_2 = this.createBranch('Filter.Out', {'Pipe_3' }, 'Atmos.In');
            %oBranch_1 = matter.branch(this, 'Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            oBranch_1 = matter.branch(this, 'Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            oBranch_2 = matter.branch(this, 'Filter.Out', {'Pipe_3' }, 'Atmos.In');
            
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            if this.bManual

                this.oB1 = solver.matter.manual.branch(this.aoBranches(1));
                %this.oB2 = solver.matter.residual.branch(this.aoBranches(2));
                this.oB2 = solver.matter.manual.branch(this.aoBranches(2));

                this.toStores.Filter.toPhases.FlowPhase.bSynced = true;

                %this.toProcsF2F.Fan.switchOff();
                this.oB1.setFlowRate(0.0005);
                
                %this.oB1.bind('update', @this.updateOutFlowRate);
                this.toStores.Filter.toProcsP2P.filterproc.bind('update', @this.updateOutFlowRate);


                this.toStores.Filter.toPhases.FilteredPhase.rMaxChange = 5;

    %             this.toStores.Filter.aoPhases(2).rMaxChange = inf;
    %             this.toStores.Filter.aoPhases(1).rMaxChange = inf;

                return;

            end
            
            
            
            
            
            this.oB1 = solver.matter.iterative.branch(this.aoBranches(1));
            this.oB2 = solver.matter.iterative.branch(this.aoBranches(2));
            
            
            
            %% Solver Tuning
            
            % The flow rate is driven by the fan within branch 1, and flows
            % through a rather small filter volume. This combination leads
            % to instabilities in the flow rate. Using this parameter, the
            % solvers reduce the changes in flow rates:
            % fFlowRate = (fNewFR + iDampFR * fOldFR) / (iDampFR + 1)
            this.oB1.iDampFR = 5;
            this.oB2.iDampFR = 5;
            
            
            
            
            % Phases
            
            this.aoFilterPhases = this.toStores.Filter.aoPhases;
            this.oAtmosPhase    = this.toStores.Atmos.aoPhases(1);
            
            % As the input flow rate can change quickly due to the fan, and
            % the filter flow phase is rather small, it can help to 'sync'
            % the flow rate solvers connected to this phase. This means
            % that as soon as the flow rate of one of the solvers changes,
            % the other solvers will also immediately calculate a new FR.
%             this.aoFilterPhases(1).bSynced = true;
            this.aoFilterPhases(1).bSynced = true;
            
            
            % The phase for the adsorbed matter in the filter store has a
            % small rMaxChange (small volume) but is not really important
            % for the solving process, so increase rMaxChange manually.
            this.aoFilterPhases(2).rMaxChange = 5;
        end
    end
    
     methods (Access = protected)
        
        function updateOutFlowRate(this, ~)
            %disp('ASDASDASDASD');
            fFlowRateIn   = this.toBranches.Atmos__Out___Filter__In.fFlowRate;
            fFilteredRate = this.toStores.Filter.toProcsP2P.filterproc.fFlowRate;
            
            %disp(num2str(fFlowRateIn - fFilteredRate));
            this.oB2.setFlowRate(fFlowRateIn - fFilteredRate);
        end
         
        function printStuff(this, varargin)
            disp('PARTIALS O2');
            
            rPartialAtmosO2 = this.toStores.Atmos.toPhases.Atmos_Phase_1.arPartialMass(this.oMT.tiN2I.O2);
            rPartialBranchO2 = this.toBranches.Atmos__Out___Filter__In.aoFlows(1).arPartialMass(this.oMT.tiN2I.O2);
            
            disp(rPartialAtmosO2 - rPartialBranchO2 == 0);
            
            if rPartialAtmosO2 ~= rPartialBranchO2
                keyboard();
            end
         end
         
         
        function exec(this, ~)
            exec@vsys(this);
            
            
            
            
            fTime = this.oTimer.fTime;
            oFan  = this.toProcsF2F.Fan;
            
            %if fTime >= 100, keyboard(); end;
            
            if fTime >= 750 && fTime < 1250 && oFan.bActive % fSpeedSetpoint ~= 0
                fprintf('Fan OFF at second %f and tick %i\n', fTime, this.oTimer.iTick);
                %oFan.fSpeedSetpoint = 0;
                oFan.switchOff();
                
                if this.bManual
                    this.oB1.setFlowRate(0);
                end
                
            elseif fTime >= 1250 && ~oFan.bActive % fSpeedSetpoint ~= 40000
                fprintf('Fan ON at second %f and tick %i\n', fTime, this.oTimer.iTick);
                
                %oFan.fSpeedSetpoint = 40000;
                oFan.switchOn();
                
                
                if this.bManual
                    this.oB1.setFlowRate(0.0005);
                end
            end
        end
        
     end
    
end

