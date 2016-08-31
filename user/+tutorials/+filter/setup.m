classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            
            %%%% Tuning of the solving process %%%%
            %
            % Generally, the phases/stores and branches separately schedule
            % their own update method calls. If a phase updates, its
            % internal properties as the heat capacity, density, molar
            % mass etc. are updated. Additionally, all connected branches
            % are notified so they can re-calculate their flow rate in the
            % 'post tick' phase (i.e. after all regularly scheduled call-
            % backs were executed by the timer object). After the branches
            % update their flow rates, the phase triggers p2p and substance
            % manipulators to update, and finally calculates a new time
            % step for its own, next update call - based on rMaxChange.
            % A solver calculates its time step based on rSetChange and
            % rMaxChange, however, this behaviour will change soon.
            % Additionally, the change in the flow rate set by the solvers
            % can be dampened with iDampFR (see below).
            % If a solver calculates a new flow rate, the connected phases
            % are notified so they can do a 'massupdate', i.e. acutally
            % 'move' the mass, according to the OLD flow rate, from the one
            % connected phase to the other (depending of the sign of the
            % flow rate). If for one of the connected phases, the attribute
            % bSynced is true, all other branches connected to this phase
            % are triggered to re-calculate their flow rate as well.
            %
            % As a general rule of thumb:
            % - if the instabilities in phase masses / pressures are too
            %   high, reduce rMaxChange locally for those phases, or
            %   globally using rUpdateFrequency
            % - if a phase is failry small, activate bSynced which MIGHT
            %   help, as all connected branches calculate new flow rates as
            %   soon as one branch calculates a new one
            % - instabilities can be smoothed out using iDampFR for all
            %   connected branch solvers. However, a high value of iDampFR
            %   might lead to more inaccurate results or even to a hang up
            %   of the solver.
            % - the rSetChange/rMaxChange behaviour in the iterative solver
            %   will be changed soon, so not described here.
            
            
            % To increase the frequency of phase updates, uncomment this
            % line. This doesn't mean that the phases update ten times as
            % often, but that they increase their sensitivity towards mass
            % changes within them when calculating the next time step.
            % This can lead to more stable flow rates and with that,
            % possibly to longer instead of shorter time steps.
            % As shown below, the default values set by the phase seal
            % methods can be manually overwritten for specific phases.
            %this.oData.set('rUpdateFrequency', 100);
            
            
            
            if ~isfield('tSolverParams', 'rHighestMaxChangeDecrease')
                tSolverParams.rHighestMaxChangeDecrease = 500;
            end
            
            
            
            this@simulation.infrastructure('Tutorial_Filter', ptConfigParams, tSolverParams);
            
            
            
            
            % Creating the root object
            oExample = tutorials.filter.systems.Example(this.oSimulationContainer, 'Example');
            
            
        end
        
        
        
        function configureMonitors(this)
            
            
            %% Logging
            
            oLog = this.toMonitors.oLogger;
            
            tiLog.ALL_EMP = oLog.add('Example', 'flow_props');
            tiLog.ALL_SUB = oLog.add('Example/Filter', 'flow_props');

            
            oLog.addValue('Example:s:Cabin.toPhases.air', 'rRelHumidity', '-', 'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.air', 'afPP(this.oMT.tiN2I.CO2)', 'P_Pa', 'Partial Pressure CO2 Cabin');
            
            iCells = this.oSimulationContainer.toChildren.Example.toChildren.Filter.iCellNumber;
            
            for iK = 1:iCells
                oLog.addValue(['Example:c:Filter:s:Filter.toPhases.Absorber_',num2str(iK)], 'afMass(this.oMT.tiN2I.CO2)', 'P_kg', ['Absorbed Partial Mass CO2 Cell ',num2str(iK)]);
                oLog.addValue(['Example:c:Filter:s:Filter.toPhases.Absorber_',num2str(iK)], 'afMass(this.oMT.tiN2I.H2O)', 'P_kg', ['Absorbed Partial Mass H2O Cell ',num2str(iK)]);
            end
            %% Define Plots
            oLog.addValue('Example:c:Filter.aoBranches(1).aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'Filter Inlet Flow CO2 Ratio');
            oLog.addValue('Example:c:Filter.aoBranches(1).aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', '-', 'Filter Inlet Flow H2O Ratio');
            
            oLog.addValue('Example:c:Filter.aoBranches(end).aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', '-', 'Filter Outlet Flow CO2 Ratio');
            oLog.addValue('Example:c:Filter.aoBranches(end).aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', '-', 'Filter Outlet Flow H2O Ratio');
            
            oPlot = this.toMonitors.oPlotter;
            
            % 
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
        	oPlot.definePlotWithFilter(tiLog.ALL_SUB, 'kg', 'Tank Masses - System Filter');
            oPlot.definePlotAllWithFilter('kg/s', 'Flow Rates');

            
            oPlot.definePlotWithFilter(tiLog.ALL_EMP, 'kg', 'Tank Masses - System Example');
            
            
            
            %% Simulation length
            % Stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 900 * 1; % In seconds
            this.iSimTicks = 600;
            this.bUseTime = true;

        end
        
        function plot(this) % Plotting the results
            
            this.toMonitors.oPlotter.plot();
            
                afTime = this.toMonitors.oLogger.afTime;

            iCells = this.oSimulationContainer.toChildren.Example.toChildren.Filter.iCellNumber;
            for iIndex = 1:length(this.toMonitors.oLogger.tLogValues)
                for iK = 1:iCells
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, ['Absorbed Partial Mass CO2 Cell ',num2str(iK)])
                        miAbsorbedCO2Cell(iK) = iIndex;
                    end
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, ['Absorbed Partial Mass H2O Cell ',num2str(iK)])
                        miAbsorbedH2OCell(iK) = iIndex;
                    end
                end
                
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Relative Humidity Cabin')
                    iRelHumCabin = iIndex;
                end
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Partial Pressure CO2 Cabin')
                    iPPCO2Cabin = iIndex;
                end
                
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Flow Rate (Filter - Filter__Inflow_1___if___Cabin__Port_1)')
                    iInletFlow = iIndex;
                end
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Filter Inlet Flow H2O Ratio')
                    iInletFlowH2ORatio = iIndex;
                end
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Filter Inlet Flow CO2 Ratio')
                    iInletFlowCO2Ratio = iIndex;
                end
                
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, ['Flow Rate (Filter - Filter__Outflow_',num2str(iCells),'___if___Cabin__Port_2)'])
                    iOutletFlow = iIndex;
                end
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Filter Outlet Flow H2O Ratio')
                    iOutletFlowH2ORatio = iIndex;
                end
                if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, 'Filter Outlet Flow CO2 Ratio')
                    iOutletFlowCO2Ratio = iIndex;
                end
            end
            
            mLogDataCO2 = size(this.toMonitors.oLogger.mfLog);
            mLogDataCO2 = zeros(iCells,mLogDataCO2(1));
            for iK = 1:iCells
                mLogDataCO2(iK,:) = this.toMonitors.oLogger.mfLog(:,miAbsorbedCO2Cell(iK));
            end
            
          	mLogDataCO2(:,isnan(mLogDataCO2(iK,:)))=[];
            
            mLogDataH2O = size(this.toMonitors.oLogger.mfLog);
            mLogDataH2O = zeros(10,mLogDataH2O(1));
            for iK = 1:10
                mLogDataH2O(iK,:) = this.toMonitors.oLogger.mfLog(:,miAbsorbedH2OCell(iK));
            end
            
          	mLogDataH2O(:,isnan(mLogDataH2O(iK,:)))=[];
            
            mRelHum = this.toMonitors.oLogger.mfLog(:,iRelHumCabin);
            mRelHum(isnan(mRelHum(:,1)),:)=[];
            
            mCO2PP = this.toMonitors.oLogger.mfLog(:,iPPCO2Cabin);
            mCO2PP(isnan(mCO2PP(:,1)),:)=[];

            
            mInletFlow = this.toMonitors.oLogger.mfLog(:,iInletFlow);
            mInletFlow(isnan(mInletFlow(:,1)),:)=[];
            mInletFlowH2ORatio = this.toMonitors.oLogger.mfLog(:,iInletFlowH2ORatio);
            mInletFlowH2ORatio(isnan(mInletFlowH2ORatio(:,1)),:)=[];
            mInletFlowCO2Ratio = this.toMonitors.oLogger.mfLog(:,iInletFlowCO2Ratio);
            mInletFlowCO2Ratio(isnan(mInletFlowCO2Ratio(:,1)),:)=[];
            
            mOutletFlow = this.toMonitors.oLogger.mfLog(:,iOutletFlow);
            mOutletFlow(isnan(mOutletFlow(:,1)),:)=[];
            mOutletFlowH2ORatio = this.toMonitors.oLogger.mfLog(:,iOutletFlowH2ORatio);
            mOutletFlowH2ORatio(isnan(mOutletFlowH2ORatio(:,1)),:)=[];
            mOutletFlowCO2Ratio = this.toMonitors.oLogger.mfLog(:,iOutletFlowCO2Ratio);
            mOutletFlowCO2Ratio(isnan(mOutletFlowCO2Ratio(:,1)),:)=[];
            
            
            figure('name', 'Relative Humidity')
            grid on
            hold on
            plot(afTime, mRelHum.*100)
            xlabel('Time in s')
            ylabel('Relative Humidity in %')
                
            figure('name', 'Partial Pressure CO2')
            grid on
            hold on
            plot(afTime, mCO2PP)
            xlabel('Time in s')
            ylabel('Partial Pressure CO_2 in Pa')
            
            mCO2InletFlow = mInletFlow .* mInletFlowCO2Ratio;
            mCO2OutletFlow = mOutletFlow .* mOutletFlowCO2Ratio;
            figure('name', 'Inlet/Outlet Flowrate CO2')
            grid on
            hold on
            plot(afTime, mCO2InletFlow)
            plot(afTime, mCO2OutletFlow)
            xlabel('Time in s')
            ylabel('Flow Rate in kg/s')
            
            mH2OInletFlow = mInletFlow .* mInletFlowH2ORatio;
            mH2OOutletFlow = mOutletFlow .* mOutletFlowH2ORatio;
            figure('name', 'Inlet/Outlet Flowrate H2O')
            grid on
            hold on
            plot(afTime, mH2OInletFlow)
            plot(afTime, mH2OOutletFlow)
            xlabel('Time in s')
            ylabel('Flow Rate in kg/s')
            
            figure('name', 'Absorbed Mass CO2')
            grid on
            hold on
            for iK = 1:iCells
                plot((afTime), mLogDataCO2(iK,:))
            end
            xlabel('Time in s')
            ylabel('Absorbed Mass CO_2 in kg')
            
            figure('name', 'Absorbed Mass H2O')
            grid on
            hold on
            for iK = 1:iCells
                plot((afTime), mLogDataH2O(iK,:))
            end
            xlabel('Time in s')
            ylabel('Absorbed Mass H_2O in kg')
                
                
            
        end
        
    end
    
end

