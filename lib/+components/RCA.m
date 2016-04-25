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
        % A struct containing the interface branches. We need this because
        % the branch names will be changed when the container is sealed. 
        toInterfaceBranches = struct();
        
        % This exme needs to be set in the supersystem. It is used to
        % measure the CO2 partial pressure used to determine if a bed
        % switch is necessary.
        oReferenceExme;
        
        % Input flow rate, has to be set externally
        fFlowRate = 0;
        
        % Partial pressure limit of CO2 in the connected reference phase
        % for triggering bed switches
        fCO2Limit = 800;    % [Pa]
        
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
        
        % Initial temperature of the filter beds in [K].
        fInitialTemperature = 298.65; 
        
        % Initial pressure in [Pa]
        fTestPressure = 28900;
        
        % Initial relative humidity [-]
        rRelativeHumidity = 0.50;
        
        fPipeLength   = 0.5;
        fPipeDiameter = 0.0254/2; 
        
    end
    
    methods
        function this = RCA(oParent, sName, sAtmosphereHelper)
               this@vsys(oParent, sName, 1);
               
               this.sAtmosphereHelper = sAtmosphereHelper;
               
               eval(this.oRoot.oCfgParams.configCode(this));

        end
        
        function createMatterStructure(this)
            
            createMatterStructure@vsys(this);
            
            fSplitterVolume = 0.001;
            
            %% Distributor
            % Creating the input splitter
            matter.store(this, 'Splitter', fSplitterVolume);  % Volume in in^3 = 0.0568 ?? 
            
            % Adding a phase to the splitter
            oPhase = this.toStores.Splitter.createPhase(this.sAtmosphereHelper,  fSplitterVolume, this.fInitialTemperature, this.rRelativeHumidity, this.fTestPressure);

            % Creating the ports on the splitter
            matter.procs.exmes.gas(oPhase, 'Inlet'); 
            matter.procs.exmes.gas(oPhase, 'Outlet1');
            matter.procs.exmes.gas(oPhase, 'Outlet2');
            
            %% Adsorber Beds
            % Creating the two filter beds
            tFilterParameters = struct('fFilterTemperature', this.fInitialTemperature,...
                                       'fFilterPressure',    this.fTestPressure,...
                                       'sAtmosphereHelper',  this.sAtmosphereHelper,...
                                       'rRelativeHumidity',  this.rRelativeHumidity);
            
            components.RCA.RCA_Filter(this, 'Bed_A', 'RCA', tFilterParameters);
            components.RCA.RCA_Filter(this, 'Bed_B', 'RCA', tFilterParameters);
            
            this.oReferenceExme = this.toStores.Bed_A.toPhases.FlowPhase.toProcsEXME.Outlet;
            
            %% Merger
            % Creating the output merger
            matter.store(this, 'Merger',  fSplitterVolume);  % Volume in in^3 = 0.0568 ??
            
            % Adding a phase to the merger
            oPhase = this.toStores.Merger.createPhase(this.sAtmosphereHelper,  fSplitterVolume, this.fInitialTemperature, this.rRelativeHumidity, this.fTestPressure);
            
            % Creating the ports on the merger
            matter.procs.exmes.gas(oPhase, 'Inlet1');
            matter.procs.exmes.gas(oPhase, 'Inlet2');
            matter.procs.exmes.gas(oPhase, 'Outlet');

            %% Vacuum Store
            % Creating vacuum store
            matter.store(this, 'Vacuum', 1000);

            % Creating empty gas phase
            oVacuum = this.toStores.Vacuum.createPhase('air', 0.000001, this.fInitialTemperature);
            
            % Constant pressure exmes for the linear solver, for both the
            % flow volume and amine phases.
            special.matter.const_press_exme(oVacuum, 'Inlet_Bed_A_FlowVolume', 0);
            special.matter.const_press_exme(oVacuum, 'Inlet_Bed_B_FlowVolume', 0);
%             special.matter.const_press_exme(oVacuum, 'Inlet_Bed_A_Amine', 0);
%             special.matter.const_press_exme(oVacuum, 'Inlet_Bed_B_Amine', 0);

            %% Adding valves
            % True/false decides if the valve is open or closed and the
            % value to the right is the length of the valve, but that is not
            % important for the further calculation.
            components.valve(this, 'Valve_1', true , 0.05);
            components.valve(this, 'Valve_2', true , 0.05);
            components.valve(this, 'Valve_3', false, 0.05);
            components.valve(this, 'Valve_4', false, 0.05);
%             components.valve(this, 'Valve_5', false, 0.05);
%             components.valve(this, 'Valve_6', true , 0.05);
            components.valve(this, 'Valve_7', false, 0.05);
            components.valve(this, 'Valve_8', true , 0.05);
            
            %% Adding pipes
            % Adding pipes to connect the components
            components.pipe(this, 'Pipe_1', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_2', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_3', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_4', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_5', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_6', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_7', this.fPipeLength, this.fPipeDiameter);
            components.pipe(this, 'Pipe_8', this.fPipeLength, this.fPipeDiameter);
            
            % The following pipes form the connection between filter and
            % Vacuum. Through adjusting the diameter and length we can
            % decide how fast the gas flows into Vacuum. So we can adjust
            % the time needed for the desorption process. Unfortunately the
            % pipe properties could reach unrealistic values
            fSmallificationFactor = 0.5;
%             components.pipe(this, 'Pipe_9',  this.fPipeLength, this.fPipeDiameter / 10);
%             components.pipe(this, 'Pipe_10', this.fPipeLength, this.fPipeDiameter / 10);
%             components.pipe(this, 'Pipe_11', this.fPipeLength, this.fPipeDiameter / 10);
%             components.pipe(this, 'Pipe_12', this.fPipeLength, this.fPipeDiameter / 10);
            components.pipe(this, 'Pipe_13', this.fPipeLength, this.fPipeDiameter / fSmallificationFactor);
            components.pipe(this, 'Pipe_14', this.fPipeLength, this.fPipeDiameter / fSmallificationFactor);
            components.pipe(this, 'Pipe_15', this.fPipeLength, this.fPipeDiameter / fSmallificationFactor);
            components.pipe(this, 'Pipe_16', this.fPipeLength, this.fPipeDiameter / fSmallificationFactor);
            
            %% Creating the flowpath between the components
            % Splitter to Bed A
            matter.branch(this, 'Splitter.Outlet1',{'Pipe_1','Valve_1','Pipe_2'},'Bed_A.Inlet');
               
            % Splitter to Bed B
            matter.branch(this, 'Splitter.Outlet2',{'Pipe_5','Valve_3','Pipe_6'},'Bed_B.Inlet');
            
            % Bed A to Merger
            matter.branch(this, 'Bed_A.Outlet',{'Pipe_3','Valve_2','Pipe_4' },'Merger.Inlet1');
            
            % Bed B to Merger
            matter.branch(this, 'Bed_B.Outlet',{'Pipe_7','Valve_4','Pipe_8' },'Merger.Inlet2');
            
%             % Bed A Amine to Vacuum
%             matter.branch(this, 'Bed_A.Amine_Vacuum_Port',{'Pipe_9','Valve_5','Pipe_10'},'Vacuum.Inlet_Bed_A_Amine');
%             
%             % Bed B Amine to Vacuum
%             matter.branch(this, 'Bed_B.Amine_Vacuum_Port',{'Pipe_11','Valve_6','Pipe_12'},'Vacuum.Inlet_Bed_B_Amine');
            
            % Bed A Flow Phase to Vacuum
            matter.branch(this, 'Bed_A.FlowVolume_Vacuum_Port',{'Pipe_13','Valve_7','Pipe_14'},'Vacuum.Inlet_Bed_A_FlowVolume');
            
            % Bed B Flow Phase to Vacuum
            matter.branch(this, 'Bed_B.FlowVolume_Vacuum_Port',{'Pipe_15','Valve_8','Pipe_16'},'Vacuum.Inlet_Bed_B_FlowVolume');
            
            % Spliter to Inlet
            this.toInterfaceBranches.Inlet = matter.branch(this, 'Splitter.Inlet', {}, 'Inlet');
            
            % Merger to Outlet
            this.toInterfaceBranches.Outlet = matter.branch(this, 'Merger.Outlet',  {}, 'Outlet');
            
        end
        
        function createSolverStructure(this)
            
            createSolverStructure@vsys(this);
            
            % Now we can create all of the solver branches
            oB1  = solver.matter.iterative.branch(this.toBranches.Splitter__Outlet1___Bed_A__Inlet);
            oB2  = solver.matter.iterative.branch(this.toBranches.Splitter__Outlet2___Bed_B__Inlet);
%             oB3  = solver.matter.iterative.branch(this.toBranches.Bed_A__Amine_Vacuum_Port___Vacuum__Inlet_Bed_A_Amine);
%             oB4  = solver.matter.iterative.branch(this.toBranches.Bed_B__Amine_Vacuum_Port___Vacuum__Inlet_Bed_B_Amine);          
            oB5  = solver.matter.manual.branch(this.toBranches.Bed_A__FlowVolume_Vacuum_Port___Vacuum__Inlet_Bed_A_FlowVolume);
            oB6  = solver.matter.manual.branch(this.toBranches.Bed_B__FlowVolume_Vacuum_Port___Vacuum__Inlet_Bed_B_FlowVolume);
            oB7  = solver.matter.iterative.branch(this.toBranches.Bed_A__Outlet___Merger__Inlet1);
            oB8  = solver.matter.iterative.branch(this.toBranches.Bed_B__Outlet___Merger__Inlet2);
            oB9  = solver.matter.iterative.branch(this.toInterfaceBranches.Outlet);
            oB10 = solver.matter.iterative.branch(this.toInterfaceBranches.Inlet);
            
            % Through experimentation, the following damping factor has
            % proven the optimal compromise between execution speed and
            % 'niceness' of the resulting plots. 
            iDampingFactor = 10;
            
            % Setting the damping factor on all branches. 
            oB1.iDampFR  = iDampingFactor;
            oB2.iDampFR  = iDampingFactor;
%             oB3.iDampFR  = iDampingFactor;
%             oB4.iDampFR  = iDampingFactor;
%             oB5.iDampFR  = iDampingFactor;
%             oB6.iDampFR  = iDampingFactor;
            oB7.iDampFR  = iDampingFactor;
            oB8.iDampFR  = iDampingFactor;
            oB9.iDampFR  = iDampingFactor;
            oB10.iDampFR = iDampingFactor;
            
            oB5.setFlowRate(0);
            oB6.setFlowRate(10000);
            
            % Again in an effort to optimize execution speed and result
            % quality, we set a lower rMaxChange value on the flow phases
            % in both adsorber beds and a high rMaxChange in the filtered
            % phases, because we don't really care about their properties
            % a lot, so they don't have to be updated that often. 
            this.toStores.Bed_A.toPhases.FilteredPhase.rMaxChange = 0.1;
            this.toStores.Bed_B.toPhases.FilteredPhase.rMaxChange = 0.1;
            
            this.toStores.Vacuum.toPhases.Vacuum_Phase_1.rMaxChange = 0.5;

            this.toStores.Splitter.toPhases.Splitter_Phase_1.bSynced = true;
            this.toStores.Bed_A.toPhases.FlowPhase.bSynced           = true;
            this.toStores.Bed_B.toPhases.FlowPhase.bSynced           = true;
            this.toStores.Merger.toPhases.Merger_Phase_1.bSynced     = true;

        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
%             if this.oTimer.fTime > 50 && strcmp(this.sActiveBed, 'A')
%                 this.switchRCABeds();
%             end
            
            % Getting the partial pressure of CO2 at the exme we have
            % defined to be the reference for this measurement. 
%             afExmePartialPressures = this.oReferenceExme.oFlow.getPartialPressures();
            afExmePartialPressures = this.oReferenceExme.oFlow.afPartialPressure;
            fMeasuredCO2PartialPressure = afExmePartialPressures(this.oMT.tiN2I.CO2);

            % We need some deadband to prevent the valve from switching too fast at
            % high metabolic rates. This is also done in the actual hardware setup of
            % PLSS 1.0
            this.fDeltaTime = this.oTimer.fTime - this.fLastBedSwitch;
            
            % Switching beds and setting flow rates if conditions are met
            if  (fMeasuredCO2PartialPressure >= this.fCO2Limit) && (this.fDeltaTime > this.fDeadband)
                this.switchRCABeds();
            end
            
        end
        
    end
    
    
    methods
        
        function setInterfaces(this, sInlet, sOutlet)
            % Setting both the interface flows as well as the reference
            % exme that will be used to measure the CO2 partial pressure
            % used to determine if a bed switch is necessary. 
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
        end
        

        function switchRCABeds(this)
            
            % To make the code more readable, the active bed is described
            % by a character. While in this if condition, we also start the
            % desorption process for the current active bed.
            
            if this.sActiveBed == 'A'
                % Setting the indicator and changing the active bed
                bIndicator = false; 
                this.sActiveBed = 'B';
                
                % Starting desorption process for Bed A 
                this.toStores.Bed_A.toProcsP2P.SorptionProcessor.desorption(this.rDesorptionRatio);
                this.toStores.Bed_B.toProcsP2P.SorptionProcessor.reset_timer(this.oTimer.fTime);
                
                this.oReferenceExme = this.toStores.Bed_B.toPhases.FlowPhase.toProcsEXME.Outlet;
                
                this.toBranches.Bed_A__FlowVolume_Vacuum_Port___Vacuum__Inlet_Bed_A_FlowVolume.oHandler.setFlowRate(10000);
                this.toBranches.Bed_B__FlowVolume_Vacuum_Port___Vacuum__Inlet_Bed_B_FlowVolume.oHandler.setFlowRate(0);
                
                % Notifying the user
                %TODO This should be put somewhere in the debugging system
                % as a low level selectable output
                fprintf('%i\t(%.7fs)\tRCA switching from bed A to bed B.\n', this.oTimer.iTick, this.oTimer.fTime);
            else
                % Setting the indicator and changing the active bed
                bIndicator = true;
                this.sActiveBed = 'A';
                
                % Starting desorption process for Bed B                
                this.toStores.Bed_B.toProcsP2P.SorptionProcessor.desorption(this.rDesorptionRatio);
                this.toStores.Bed_A.toProcsP2P.SorptionProcessor.reset_timer(this.oTimer.fTime);
                
                this.oReferenceExme = this.toStores.Bed_A.toPhases.FlowPhase.toProcsEXME.Outlet;
                
                this.toBranches.Bed_A__FlowVolume_Vacuum_Port___Vacuum__Inlet_Bed_A_FlowVolume.oHandler.setFlowRate(0);
                this.toBranches.Bed_B__FlowVolume_Vacuum_Port___Vacuum__Inlet_Bed_B_FlowVolume.oHandler.setFlowRate(10000);
                
                % Notifying the user
                %TODO This should be put somewhere in the debugging system
                % as a low level selectable output
                fprintf('%i\t(%.7fs)\tRCA switching from bed B to bed A.\n', this.oTimer.iTick, this.oTimer.fTime);
            end
            
            % Changing the valves
            % Bed flow
            this.toProcsF2F.Valve_1.setValvePos(bIndicator);
            this.toProcsF2F.Valve_2.setValvePos(bIndicator);
            this.toProcsF2F.Valve_3.setValvePos(~bIndicator);
            this.toProcsF2F.Valve_4.setValvePos(~bIndicator);
            
            % Vacuum flow
%             this.toProcsF2F.Valve_5.setValvePos(~bIndicator);
%             this.toProcsF2F.Valve_6.setValvePos(bIndicator);
            this.toProcsF2F.Valve_7.setValvePos(~bIndicator);
            this.toProcsF2F.Valve_8.setValvePos(bIndicator);
            
            % Resetting the timer
            this.fLastBedSwitch = this.oTimer.fTime;         
        end
    end
    

end




