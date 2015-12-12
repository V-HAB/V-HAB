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
    end
    
    methods
        function this = Example1(oParent, sName)
            this@vsys(oParent, sName, 10);
           
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
            components.fan(this, 'Fan', 'setSpeed', 40000, 'Left2Right');
            
            % Adding pipes to connect the components
            components.pipe(this, 'Pipe_1', 0.5, 0.005);
            components.pipe(this, 'Pipe_2', 0.5, 0.005);
            components.pipe(this, 'Pipe_3', 0.5, 0.005);
            
            % Creating the flowpath (=branch) between the components
            % Since we are using default exme-processors here, the input
            % format can be 'store.phase' instead of 'store.exme'
            %oBranch_1 = this.createBranch('Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            %oBranch_2 = this.createBranch('Filter.Out', {'Pipe_3' }, 'Atmos.In');
            oBranch_1 = matter.branch(this, 'Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            oBranch_2 = matter.branch(this, 'Filter.Out', {'Pipe_3' }, 'Atmos.In');
            
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            
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
        
        function exec(this, ~)
            exec@vsys(this);
            
            
            
            fTime = this.oTimer.fTime;
            oFan  = this.toProcsF2F.Fan;
            
            %if fTime >= 100, keyboard(); end;
            
            if fTime >= 750 && fTime < 1250 && oFan.fSpeedSetpoint ~= 0
                fprintf('Fan OFF at second %f and tick %i\n', fTime, this.oTimer.iTick);
                oFan.fSpeedSetpoint = 0;
                
            elseif fTime >= 1250 && oFan.fSpeedSetpoint ~= 40000
                fprintf('Fan ON at second %f and tick %i\n', fTime, this.oTimer.iTick);
                
                oFan.fSpeedSetpoint = 40000;
            end
        end
        
     end
    
end

