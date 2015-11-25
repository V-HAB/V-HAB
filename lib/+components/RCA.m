classdef RCA < vsys
    %RCA Simulation model of the Rapid Cycle Amine swing bed CO2 absorber
    %
    %   Update description!
    %
    %   The distributor tank is connected with the filter unit with
    %   pipes in a loop. The filter consists of two beds which are able to
    %   switch when one bed is saturated. The two beds are also connected via
    %   pipes with the vacuum, so they can be desorbed if they are in the
    %   respective state.
    
    properties
        % A struct containing all the necessary manual solver branches
        toManualBranches = struct();
        
        % Input flow rate, has to be set externally
        fFlowRate = 0;
        
        % Pressure at which the testloop runs
        fTestPressure = 28270;  % [Pa]
        
        % Partial pressure limit of CO2 in the connected reference phase
        % for triggering bed switches
        fCO2Limit = 6.5;    % [mmHg]
        
        % Partial pressure of CO2
        fPP_CO2Out = 0;     % at the outlet
        fPP_CO2In = 0;      % at the inlet
          
        % Choose the efficiency of the desorption
        % Are the beds emptied completely => rDesorptionRatio = 1
        % or just partely => rDesorptionRatio < 1
        rDesorptionRatio = 1;   % [-]
        
        % Time of last bed switch
        fLastBedSwitch = 0;
        
        % Passed time since the last bed switch
        fDeltaTime; 
        
        % Deadband in seconds, minimum time between bed switches to prevent
        % immediate set back due to inaccuracies after the bed switch
        fDeadband = 10;     % [s]        
        
        % A string indicating which bed is currently the active one
        sActiveBed = 'A';
        
        % A string containing the phase creation helper used for the phases
        % of the RCA filters. 
        sAtmosphereHelper; 
        
    end
    
    methods
        function this = RCA(oParent, sName, sAtmosphereHelper)
               this@vsys(oParent, sName, -1);
               
               this.sAtmosphereHelper = sAtmosphereHelper;
        end
        
        function createMatterStructure(this)
            
            createMatterStructure@vsys(this);
            
            %% Distributor
            %
            % !!! Actually much too big, but smaller volume needs either
            % much more calls (slow simulation) or leads to fluctuation in
            % the numerical calculation. !!!
            % BUT: needed ???
            %
            % Creating the input splitter
            matter.store(this, 'Splitter', 0.004);  % Volume in in^3 = 0.0568 ?? 
            % Adding a phase to the splitter
            oPhase = this.toStores.Splitter.createPhase(this.sAtmosphereHelper,  0.004, 298.65);
            % Creating the ports on the splitter
            matter.procs.exmes.gas(oPhase, 'Splitter_Inlet'); 
            matter.procs.exmes.gas(oPhase, 'Splitter_Outlet1');
            matter.procs.exmes.gas(oPhase, 'Splitter_Outlet2');
            % Add a fixed time step
            %oPhase.fFixedTS = 0.7;
            
            %% Adsorber Beds
            % Creating the two filter beds
            tFilterParameters = struct('fFilterTemperature', 298.65,...
                                       'sAtmospherHelper',   this.sAtmosphereHelper,...
                                       'fTimeStep',          1);
                                   
            components.RCA.RCA_Filter(this, 'Bed_A', 'RCA', tFilterParameters);
            components.RCA.RCA_Filter(this, 'Bed_B', 'RCA', tFilterParameters);
            
            %% Merger
            %
            % !!! Actually much too big. Could lead to similar problems as 
            % described for the Distributor. !!!
            % BUT: needed ???
            %           
            % Creating the output merger
            matter.store(this, 'Merger',  0.004);  % Volume in in^3 = 0.0568 ??
            % Adding a phase to the merger
            oPhase = this.toStores.Merger.createPhase(this.sAtmosphereHelper,  0.004, 298.65);
            % For all of the solver branches to update correctly and
            % simultaneously, this phase has to be 'synced'
%             oPhase.bSynced = true;
            
            % Creating the ports on the merger
            matter.procs.exmes.gas(oPhase, 'Merger_Inlet1');
            matter.procs.exmes.gas(oPhase, 'Merger_Inlet2');
            matter.procs.exmes.gas(oPhase, 'Merger_Outlet');
            
            %% Vacuum Store
            % Creating vacuum store
            matter.store(this, 'Vacuum', 1000);
            % Creating empty gas phase
            oVacuum = this.toStores.Vacuum.createPhase('air', 0, 298.65, 0, 0);
            % Constant pressure exmes for the linear solver, for both the
            % flow volume and amine phases.
            special.matter.const_press_exme(oVacuum, 'Inlet_Bed_A_FlowVolume', 0);
            special.matter.const_press_exme(oVacuum, 'Inlet_Bed_B_FlowVolume', 0);
            special.matter.const_press_exme(oVacuum, 'Inlet_Bed_A_Amine', 0);
            special.matter.const_press_exme(oVacuum, 'Inlet_Bed_B_Amine', 0);

            %% Adding valves
            % True/false decides if the valve is open or closed and the
            % value to the right is the length of the valve, but that is not
            % important for the further calculation.
            components.valve(this, 'Valve_1', true  ,0.05);
            components.valve(this, 'Valve_2', true  ,0.05);
            components.valve(this, 'Valve_3', false ,0.05);
            components.valve(this, 'Valve_4', false ,0.05);
            components.valve(this, 'Valve_5', false ,0.05);
            components.valve(this, 'Valve_6', true  ,0.05);
            components.valve(this, 'Valve_7', false ,0.05);
            components.valve(this, 'Valve_8', true  ,0.05);
            
            %% Adding pipes
            % Adding pipes to connect the components (14,8: 1 inch Al-Tube = 25.4mm)
            % Diameter and length have no influence on pressure or flow rate
            % if we use the manual solver, if you use the linear solver, then
            % the dimensions have an influence only on the pressure!
            % little diameter -> high pressures at filter Port Out
            % short length -> low pressures at filter PortOut
            % if the length is too short we get mistakes, because if there
            % is no pressure left, the flow rate is zero!
            % The reason for these observation is that a thinner and longer
            % pipe builds up a higher pressure.
            % But the flow rate is nearly constant, because the linear
            % solver calculates a coefficient which equalizes changes in
            % diameter or length!
            % I calculate the outgoing partial pressure with the flow
            % rate, so the changes in diameter or length do not
            % influence this setup
            components.pipe(this, 'Pipe_1', 0.8, 0.0254);
            components.pipe(this, 'Pipe_2', 0.8, 0.0254);
            components.pipe(this, 'Pipe_3', 0.8, 0.0254);
            components.pipe(this, 'Pipe_4', 0.8, 0.0254);
            components.pipe(this, 'Pipe_5', 0.8, 0.0254);
            components.pipe(this, 'Pipe_6', 0.8, 0.0254);
            components.pipe(this, 'Pipe_7', 0.8, 0.0254);
            components.pipe(this, 'Pipe_8', 0.8, 0.0254);
            
            % The following pipes form the connection between filter and
            % Vacuum. Through adjusting the diameter and length we can
            % decide how fast the gas flows into Vacuum. So we can adjust
            % the time needed for the desorption process. Unfortunately the
            % pipe properties could reach unrealistic values
            components.pipe(this, 'Pipe_9',  0.8, 0.00254);
            components.pipe(this, 'Pipe_10', 0.8, 0.00254);
            components.pipe(this, 'Pipe_11', 0.8, 0.00254);
            components.pipe(this, 'Pipe_12', 0.8, 0.00254);
            components.pipe(this, 'Pipe_13', 0.8, 0.00254);
            components.pipe(this, 'Pipe_14', 0.8, 0.00254);
            components.pipe(this, 'Pipe_15', 0.8, 0.00254);
            components.pipe(this, 'Pipe_16', 0.8, 0.00254);
            
            %% Creating the flowpath between the components
            % BED A - INLET
            matter.branch(this, 'Splitter.Splitter_Outlet1',{'Pipe_1','Valve_1','Pipe_2'},'Bed_A.Inlet');
               
            % BED B - INLET
            matter.branch(this, 'Splitter.Splitter_Outlet2',{'Pipe_5','Valve_3','Pipe_6'},'Bed_B.Inlet');
            
            % BED A - OUTLET
            matter.branch(this, 'Bed_A.Outlet',{'Pipe_3','Valve_2','Pipe_4' },'Merger.Merger_Inlet1');
            
            % BED B - OUTLET
            matter.branch(this, 'Bed_B.Outlet',{'Pipe_7','Valve_4','Pipe_8' },'Merger.Merger_Inlet2');
            
            % VACUUM <-> BED A (amine)
            matter.branch(this, 'Bed_A.Amine_Vacuum_Port',{'Pipe_9','Valve_5','Pipe_10'},'Vacuum.Inlet_Bed_A_Amine');
            
            % VACUUM <-> BED B (amine)
            matter.branch(this, 'Bed_B.Amine_Vacuum_Port',{'Pipe_11','Valve_6','Pipe_12'},'Vacuum.Inlet_Bed_B_Amine');
            
            % VACUUM <-> BED A (flow volume)
            matter.branch(this, 'Bed_A.FlowVolume_Vacuum_Port',{'Pipe_13','Valve_7','Pipe_14'},'Vacuum.Inlet_Bed_A_FlowVolume');
            
            % VACUUM <-> BED B (flow volume)
            matter.branch(this, 'Bed_B.FlowVolume_Vacuum_Port',{'Pipe_15','Valve_8','Pipe_16'},'Vacuum.Inlet_Bed_B_FlowVolume');
            
            % Creating the flowpath for the connection on the RCATest level
            % RCA INLET
            this.toManualBranches.Inlet = matter.branch(this, 'Splitter.Splitter_Inlet', {}, 'Inlet');
            
            % RCA OUTLET
            this.toManualBranches.Outlet = matter.branch(this, 'Merger.Merger_Outlet',  {}, 'Outlet');
            
        end
        
        function createSolverStructure(this)
            % Now we can create all of the solver branches
            solver.matter.manual.branch(this.toBranches.Splitter__Splitter_Outlet1___Bed_A__Inlet);
            solver.matter.manual.branch(this.toBranches.Splitter__Splitter_Outlet2___Bed_B__Inlet);
            solver.matter.iterative.branch(this.toBranches.Bed_A__Amine_Vacuum_Port___Vacuum__Inlet_Bed_A_Amine);
            solver.matter.iterative.branch(this.toBranches.Bed_B__Amine_Vacuum_Port___Vacuum__Inlet_Bed_B_Amine);          
            solver.matter.iterative.branch(this.toBranches.Bed_A__FlowVolume_Vacuum_Port___Vacuum__Inlet_Bed_A_FlowVolume);
            solver.matter.iterative.branch(this.toBranches.Bed_B__FlowVolume_Vacuum_Port___Vacuum__Inlet_Bed_B_FlowVolume);
%             solver.matter.iterative.branch(this.toBranches.Bed_A__Outlet___Merger__Merger_Inlet1);
%             solver.matter.iterative.branch(this.toBranches.Bed_B__Outlet___Merger__Merger_Inlet2);
            solver.matter.manual.branch(this.toBranches.Bed_A__Outlet___Merger__Merger_Inlet1);
            solver.matter.manual.branch(this.toBranches.Bed_B__Outlet___Merger__Merger_Inlet2);
            this.toManualBranches.Inlet  = solver.matter.manual.branch(this.toBranches.(this.toManualBranches.Inlet.sName));
            this.toManualBranches.Outlet = solver.matter.manual.branch(this.toBranches.(this.toManualBranches.Outlet.sName));
            
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            % Set flow rates
            this.setFlowRates;
            
            % Getting the current partial pressure of CO2 at the bed inlet
            % and the bed outlet in [Pa]
            if this.sActiveBed == 'A'
                afPartialPressures = this.toStores.Bed_A.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.getPartialPressures();
                this.fPP_CO2In     = afPartialPressures(this.oMT.tiN2I.CO2);                      % inlet pressure 
                this.fPP_CO2In     = this.fPP_CO2In * 7.5006e-3; % [mmHg]
                this.fPP_CO2Out    = this.toStores.Bed_A.toProcsP2P.filterproc_sorp.fC_CO2Out;    % outlet pressure
            elseif this.sActiveBed == 'B'
                afPartialPressures = this.toStores.Bed_B.toPhases.FlowPhase.toProcsEXME.Inlet.oFlow.getPartialPressures();
                this.fPP_CO2In     = afPartialPressures(this.oMT.tiN2I.CO2);                      % inlet pressure  
                this.fPP_CO2In     = this.fPP_CO2In * 7.5006e-3; % [mmHg]
                this.fPP_CO2Out    = this.toStores.Bed_B.toProcsP2P.filterproc_sorp.fC_CO2Out;    % outlet pressure
            end
            
            % We need some deadband to prevent the valve from switching too fast at
            % high metabolic rates. This is also done in the actual hardware setup of
            % PLSS 1.0
            this.fDeltaTime = this.oTimer.fTime - this.fLastBedSwitch;
            % Switching beds and setting flow rates if conditions are met
            if  (this.fPP_CO2Out >= this.fCO2Limit) && (this.fDeltaTime > this.fDeadband)
                this.switchRCABeds;
                this.setFlowRates;
            end
        end
        
    end
    
    
    methods
        
        function setIfFlows(this, sInlet, sOutlet)
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
        end
        
        function setFlowRates(this)
            
            % Setting the Inlet flow rate manually
            this.toManualBranches.Inlet.setFlowRate(-this.fFlowRate);
            
            % Setting the flow rate values for the beds
            if this.sActiveBed == 'A'
                fFlowRate_A = this.fFlowRate;
                fFlowRate_B = 0;
            else
                fFlowRate_A = 0;
                fFlowRate_B = this.fFlowRate;
            end
            % Assinging the flow rates to the manual branches
            this.toBranches.Splitter__Splitter_Outlet1___Bed_A__Inlet.oHandler.setFlowRate(fFlowRate_A);
            this.toBranches.Splitter__Splitter_Outlet2___Bed_B__Inlet.oHandler.setFlowRate(fFlowRate_B);
              
            % Setting outlet flows
            if this.sActiveBed == 'A'
                % Setting the flow rate for the bed outlet
                this.toBranches.Bed_A__Outlet___Merger__Merger_Inlet1.oHandler.setFlowRate(...
                    fFlowRate_A ...
                    - this.toStores.Bed_A.toProcsP2P.filterproc_sorp.fFlowRate ...
                    - this.toStores.Bed_A.toProcsP2P.filterproc_deso.fFlowRate);
                % And the according flow rate from the merger to the higher
                % system level
                this.toManualBranches.Outlet.setFlowRate(this.toBranches.Bed_A__Outlet___Merger__Merger_Inlet1.oHandler.fRequestedFlowRate);
%                 this.toManualBranches.Outlet.setFlowRate(this.toBranches.Bed_A__Outlet___Merger__Merger_Inlet1.oHandler.fFlowRate);
            else
                this.toBranches.Bed_B__Outlet___Merger__Merger_Inlet2.oHandler.setFlowRate(...
                    fFlowRate_B ...
                    - this.toStores.Bed_B.toProcsP2P.filterproc_sorp.fFlowRate ...
                    - this.toStores.Bed_B.toProcsP2P.filterproc_deso.fFlowRate);
                this.toManualBranches.Outlet.setFlowRate(this.toBranches.Bed_B__Outlet___Merger__Merger_Inlet2.oHandler.fRequestedFlowRate);
%                 this.toManualBranches.Outlet.setFlowRate(this.toBranches.Bed_B__Outlet___Merger__Merger_Inlet2.oHandler.fFlowRate);
            end       
            
            % TESTLOOP CASE: keep the spacesuit at a constant pressure by
            % replacing filtered gas with N2 or compensate overpressuring
            % through metabolic rates
            if strcmp(this.oParent.sName, 'Testloop')
                N2_FlowRate = - this.toManualBranches.Inlet.fRequestedFlowRate ...
                    - this.toManualBranches.Outlet.fRequestedFlowRate ...
                    - this.oParent.toManualBranches.H2O.fFlowRate ...
                    - this.oParent.toManualBranches.CO2.fFlowRate;
                this.oParent.toManualBranches.N2.setFlowRate(N2_FlowRate);
            end
            
        end
        
        function switchRCABeds(this)
            
            % To make the code more readable, the active bed is described by a character.
            % Internally, the switch between the beds is done via boolean variables. So
            % to make things easier, here we translate the character to boolean and use
            % the resulting indicator variable to set the valves accordingly.
            
            % While in this if condition, we also start the desorption process for the 
            % current active bed.
            
            if this.sActiveBed == 'A'
                % Setting the indicator and changing the active bed
                bIndicator = false; 
                this.sActiveBed = 'B';
                
                % Starting desorption process for Bed A 
                this.toStores.Bed_A.toProcsP2P.filterproc_sorp.desorption(this.rDesorptionRatio);
                this.toStores.Bed_B.toProcsP2P.filterproc_sorp.reset_timer(this.oTimer.fTime);
                
                % Notifying the user
                %TODO This should be put somewhere in the debugging system
                % as a low level selectable output
                fprintf('RCA switching from bed A to bed B.\n');
            else
                % Setting the indicator and changing the active bed
                bIndicator = true;
                this.sActiveBed = 'A';
                
                % Starting desorption process for Bed B                
                this.toStores.Bed_B.toProcsP2P.filterproc_sorp.desorption(this.rDesorptionRatio);
                this.toStores.Bed_A.toProcsP2P.filterproc_sorp.reset_timer(this.oTimer.fTime);
                
                % Notifying the user
                %TODO This should be put somewhere in the debugging system
                % as a low level selectable output
                fprintf('RCA switching from bed B to bed A.\n');
            end
            
            % Changing the valves
            % Bed flow
            this.toProcsF2F.Valve_1.setValvePos(bIndicator);
            this.toProcsF2F.Valve_2.setValvePos(bIndicator);
            this.toProcsF2F.Valve_3.setValvePos(~bIndicator);
            this.toProcsF2F.Valve_4.setValvePos(~bIndicator);
            
            % Vacuum flow
            this.toProcsF2F.Valve_5.setValvePos(~bIndicator);
            this.toProcsF2F.Valve_6.setValvePos(bIndicator);
            this.toProcsF2F.Valve_7.setValvePos(~bIndicator);
            this.toProcsF2F.Valve_8.setValvePos(bIndicator);
            
            % Resetting the timer
            this.fLastBedSwitch = this.oTimer.fTime;         
        end
    end
    

end




