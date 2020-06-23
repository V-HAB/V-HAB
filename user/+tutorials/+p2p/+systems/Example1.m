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
            
             % Create the filter. See the according files, just an example
            % for an implementation - copy to your own directory and change
            % as needed.
            fFilterVolume = 1;
            matter.store(this, 'Filter', fFilterVolume);
            oFlow = this.toStores.Filter.createPhase('air', 'FlowPhase', fFilterVolume/ 2, 293.15);
            
            oFiltered = matter.phases.gas(this.toStores.Filter, ...
                          'FilteredPhase', ... Phase name
                          struct(), ... Phase contents
                          fFilterVolume / 2, ... Phase volume
                          293.15); % Phase temperature 
            
            % Create the according exmes - default for the external
            % connections, i.e. the air stream that should be filtered. The
            % filterports are internal ones for the p2p processor to use.
            matter.procs.exmes.gas(oFlow,     'In');
            matter.procs.exmes.gas(oFlow,     'In_P2P');
            matter.procs.exmes.gas(oFlow,  	  'Out');
            matter.procs.exmes.gas(oFiltered, 'Out_P2P');
            
            % Creating the p2p processor
            % Input parameters: name, flow phase name, absorber phase name, 
            % species to be filtered, filter capacity
            fSubstance = 'O2';
            fCapacity = 0.5;
            tutorials.p2p.components.AbsorberExample(this.toStores.Filter, 'filterproc', 'FlowPhase.In_P2P', 'FilteredPhase.Out_P2P', fSubstance, fCapacity);
            
            % Adding a fan
            components.matter.fan(this, 'Fan', 40000, true);
            
            % Adding pipes to connect the components
            components.matter.pipe(this, 'Pipe_1', 0.5, 0.005);
            components.matter.pipe(this, 'Pipe_2', 0.5, 0.005);
            components.matter.pipe(this, 'Pipe_3', 0.5, 0.005);
            
            % Creating the flowpath (=branch) between the components
            % Since we are using default exme-processors here, the input
            % format can be 'store.phase' instead of 'store.exme'
            matter.branch(this, 'Atmos.Out', { 'Pipe_1', 'Fan', 'Pipe_2' }, 'Filter.In');
            matter.branch(this, 'Filter.Out', {'Pipe_3' }, 'Atmos.In');
            
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            if this.bManual

                this.oB1 = solver.matter.manual.branch(this.aoBranches(1));
                this.oB2 = solver.matter.residual.branch(this.aoBranches(2));
                %this.oB2 = solver.matter.manual.branch(this.aoBranches(2));

                this.toStores.Filter.toPhases.FlowPhase.bSynced = true;

                this.oB1.setFlowRate(0.0005);
                
                tTimeStepProperties.rMaxChange = 10;
                this.toStores.Filter.toPhases.FilteredPhase.setTimeStepProperties(tTimeStepProperties);

    %             this.toStores.Filter.aoPhases(2).rMaxChange = inf;
    %             this.toStores.Filter.aoPhases(1).rMaxChange = inf;

                this.setThermalSolvers();
                return;

            end
            
            
            
            
            
            this.oB1 = solver.matter.interval.branch(this.aoBranches(1));
            this.oB2 = solver.matter.interval.branch(this.aoBranches(2));
            
            
            
            %% Solver Tuning
            
            % The flow rate is driven by the fan within branch 1, and flows
            % through a rather small filter volume. This combination leads
            % to instabilities in the flow rate. Using this parameter, the
            % solvers reduce the changes in flow rates:
            % fFlowRate = (fNewFR + iDampFR * fOldFR) / (iDampFR + 1)
%             this.oB1.iDampFR = 5;
%             this.oB2.iDampFR = 5;
            
            this.toProcsF2F.Fan.switchOn();
            
            
            % Phases
            
            this.aoFilterPhases = this.toStores.Filter.aoPhases;
            this.oAtmosPhase    = this.toStores.Atmos.aoPhases(1);
            
            % The phase for the adsorbed matter in the filter store has a
            % small rMaxChange (small volume) but is not really important
            % for the solving process, so increase rMaxChange manually.
            
            tTimeStepProperties.rMaxChange = 5;
            this.aoFilterPhases(2).setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            
            
            
            fTime = this.oTimer.fTime;
            oFan  = this.toProcsF2F.Fan;
            
            %if fTime >= 100, keyboard(); end;
            
            if fTime >= 750 && fTime < 1250 && oFan.bTurnedOn % fSpeedSetpoint ~= 0
                fprintf('Fan OFF at second %f and tick %i\n', fTime, this.oTimer.iTick);
                %oFan.fSpeedSetpoint = 0;
                oFan.switchOff();
                
                if this.bManual
                    this.oB1.setFlowRate(0);
                end
                
            elseif fTime >= 1250 && ~oFan.bTurnedOn % fSpeedSetpoint ~= 40000
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

