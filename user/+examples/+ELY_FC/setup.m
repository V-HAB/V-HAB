
classdef setup < simulation.infrastructure
    
    properties
        
    end
    
    methods
        
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorConfig = struct();
            
            this@simulation.infrastructure('ELY_FC', ptConfigParams, tSolverParams, ttMonitorConfig);
            examples.ELY_FC.system.ELY_FC(this.oSimulationContainer,'ELY_FC');
            
            %simulation length
            this.fSimTime = 35000;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            oLogger = this.toMonitors.oLogger;
            
            
            % Fuel Cell Logging, currently outcommented because the Fuel
            % Cell is not simulated due to lacking literature data for
            % verification
%             oLogger.addValue('ELY_FC:c:FuelCell', 'rEfficiency',      '-',  	'Fuel Cell Efficiency');
%             oLogger.addValue('ELY_FC:c:FuelCell', 'fStackCurrent',    'A',    'Fuel Cell Current');
%             oLogger.addValue('ELY_FC:c:FuelCell', 'fStackVoltage',    'V',    'Fuel Cell Voltage');
%             oLogger.addValue('ELY_FC:c:FuelCell', 'fPower',           'W',    'Fuel Cell Power');
%             
%             oLogger.addValue('ELY_FC:c:FuelCell:s:FuelCell:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.H2)',	'kg/s',    'Fuel Cell Reaction H_2 Flow');
%             oLogger.addValue('ELY_FC:c:FuelCell:s:FuelCell:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.O2)',	'kg/s',    'Fuel Cell Reaction O_2 Flow');
%             oLogger.addValue('ELY_FC:c:FuelCell:s:FuelCell:p:Membrane.toManips.substance', 'this.afPartialFlows(this.oMT.tiN2I.H2O)',	'kg/s',    'Fuel Cell Reaction H2O Flow');
            
            oELY_FC = this.oSimulationContainer.toChildren.ELY_FC;
            % Electrolyzer Logging
            for iPressure = 1:length(oELY_FC.mfPressure)
                for iTemperature = 1:length(oELY_FC.mfTemperature)
                    sElectrolyzer = ['Electrolyzer_', num2str(oELY_FC.mfPressure(iPressure)), '_', num2str(oELY_FC.mfTemperature(iTemperature))];
                    
                    oLogger.addValue(['ELY_FC:c:', sElectrolyzer], 'rEfficiency',                   '-',  	[sElectrolyzer, ' Efficiency']);
                    oLogger.addValue(['ELY_FC:c:', sElectrolyzer], 'fStackCurrent',                 'A',    [sElectrolyzer, ' Current']);
                    oLogger.addValue(['ELY_FC:c:', sElectrolyzer], 'fStackVoltage',                 'V',    [sElectrolyzer, ' Voltage']);
                    oLogger.addValue(['ELY_FC:c:', sElectrolyzer], 'fPower',                        'W',    [sElectrolyzer, ' Power']);
                    
                    oLogger.addValue(['ELY_FC:c:', sElectrolyzer], 'fCellVoltage',                  'V',    [sElectrolyzer, ' Cell Voltage']);
                    oLogger.addValue(['ELY_FC:c:', sElectrolyzer], 'fOhmicOverpotential',           'V',    [sElectrolyzer, ' Ohmic Overpotential']);
                    oLogger.addValue(['ELY_FC:c:', sElectrolyzer], 'fKineticOverpotential',         'V',    [sElectrolyzer, ' Kinetic Overpotential']);
                    oLogger.addValue(['ELY_FC:c:', sElectrolyzer], 'fMassTransportOverpotential',  	'V',    [sElectrolyzer, ' Mass Transport Overpotential']);
                end
            end
        end
        function plot(this)
            
            close all % closes all currently open figures
            
            oELY_FC = this.oSimulationContainer.toChildren.ELY_FC;
            
            h = gobjects(length(oELY_FC.mfPressure), 3);
            
            oLogger = this.toMonitors.oLogger;
            % oLogger.afTime
            figure('Name', 'Electrolyzer Overpotential for Different Pressures and Temperatures')
            subplot(1,2,1)
            miPlotColor(1,:) = [77,175,74]  ./ 255;
            miPlotColor(2,:) = [228,26,28]  ./ 255;
            miPlotColor(3,:) = [55,126,184] ./ 255;
            for iPressure = 1:length(oELY_FC.mfPressure)
                iTemperature = oELY_FC.mfTemperature == 50;
                sElectrolyzer = ['Electrolyzer_', num2str(oELY_FC.mfPressure(iPressure)), '_', num2str(oELY_FC.mfTemperature(iTemperature))];
                
                oEly = oELY_FC.toChildren.(sElectrolyzer);
                
                csLogVariableNames = {['"', sElectrolyzer, ' Current"'], ['"', sElectrolyzer, ' Ohmic Overpotential"'], ['"', sElectrolyzer, ' Kinetic Overpotential"'], ['"', sElectrolyzer, ' Mass Transport Overpotential"']};

                [aiLogIndices, ~] = tools.findLogIndices(oLogger, csLogVariableNames);
                
                fCurrentDensity = oLogger.mfLog(:,aiLogIndices(1)) ./ (oEly.fMembraneArea * 10000); % in A/cm^2
                hold on
                h(iPressure, 1) = plot(fCurrentDensity, oLogger.mfLog(:,aiLogIndices(2)), 'Color', miPlotColor(iPressure,:), 'LineStyle', '-');
                h(iPressure, 2) = plot(fCurrentDensity, oLogger.mfLog(:,aiLogIndices(3)), 'Color', miPlotColor(iPressure,:), 'LineStyle', '--');
                h(iPressure, 3) = plot(fCurrentDensity, oLogger.mfLog(:,aiLogIndices(4)), 'Color', miPlotColor(iPressure,:), 'LineStyle', '-.');
                
                % Add test data for this pressure:
                sPressure = [num2str(oELY_FC.mfPressure(iPressure)), 'bar'];
                mfCurrentDensityKinetic  	= xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sPressure, 'B5:B100');
                mfOverpotentialKinetic  	= xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sPressure, 'C5:C100');
                mfCurrentDensityOhmic       = xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sPressure, 'E5:E100');
                mfOverpotentialOhmic        = xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sPressure, 'F5:F100');
                mfCurrentDensityMass        = xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sPressure, 'H5:H100');
                mfOverpotentialMass         = xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sPressure, 'I5:I100');
                
                scatter(mfCurrentDensityKinetic,    mfOverpotentialKinetic, 'MarkerEdgeColor', miPlotColor(iPressure,:), 'Marker', 's')
                scatter(mfCurrentDensityOhmic,      mfOverpotentialOhmic,   'MarkerEdgeColor', miPlotColor(iPressure,:), 'Marker', '>')
                scatter(mfCurrentDensityMass,       mfOverpotentialMass,    'MarkerEdgeColor', miPlotColor(iPressure,:), 'Marker', 'o')
            end
            % We jsut add empty plots to better create a legend for this
            % plot
            h(iPressure+1, 1) = plot(0, 0, 'Color', 'k', 'LineStyle', '-');
            h(iPressure+1, 2) = plot(0, 0, 'Color', 'k', 'LineStyle', '--');
            h(iPressure+1, 3) = plot(0, 0, 'Color', 'k', 'LineStyle', '-.');
            h(iPressure+1, 4) = plot(0, 0, 'Color', 'k', 'LineStyle', ':');
            
            legend([h(1, 1), h(2, 1), h(3, 1), h(4, 1), h(4, 2), h(4, 3)], '1 bar', ' 10 bar', '100 bar', 'Ohmic', 'Kinetic', 'Mass Transport', 'Location','northwest')
            grid on
            xlabel('Current Density / A/cm^2');
            ylabel('Overpotential / V');
            xlim([0,4])
            
            clear h
            
            subplot(1,2,2)
            miPlotColor(1,:) = [77,175,74]  ./ 255;
            miPlotColor(2,:) = [55,126,184] ./ 255;
            miPlotColor(3,:) = [228,26,28]  ./ 255;
            miPlotColor(4,:) = [152,78,163] ./ 255;
            miPlotColor(5,:) = [255,127,0]  ./ 255;
            for iTemperature = 1:length(oELY_FC.mfTemperature)
                iPressure = oELY_FC.mfPressure == 10;
                sElectrolyzer = ['Electrolyzer_', num2str(oELY_FC.mfPressure(iPressure)), '_', num2str(oELY_FC.mfTemperature(iTemperature))];
                
                oEly = oELY_FC.toChildren.(sElectrolyzer);
                
                csLogVariableNames = {['"', sElectrolyzer, ' Current"'], ['"', sElectrolyzer, ' Ohmic Overpotential"'], ['"', sElectrolyzer, ' Kinetic Overpotential"'], ['"', sElectrolyzer, ' Mass Transport Overpotential"']};

                [aiLogIndices, ~] = tools.findLogIndices(oLogger, csLogVariableNames);
                
                fCurrentDensity = oLogger.mfLog(:,aiLogIndices(1)) ./ (oEly.fMembraneArea * 10000); % in A/cm^2
                hold on
                h(iTemperature, 1) = plot(fCurrentDensity, oLogger.mfLog(:,aiLogIndices(2)), 'Color', miPlotColor(iTemperature,:), 'LineStyle', '-');
                h(iTemperature, 2) = plot(fCurrentDensity, oLogger.mfLog(:,aiLogIndices(3)), 'Color', miPlotColor(iTemperature,:), 'LineStyle', '--');
                h(iTemperature, 3) = plot(fCurrentDensity, oLogger.mfLog(:,aiLogIndices(4)), 'Color', miPlotColor(iTemperature,:), 'LineStyle', '-.');
                
                % Add test data for this pressure:
                sTemperature = [num2str(oELY_FC.mfTemperature(iTemperature)), '°C'];
                mfCurrentDensityKinetic  	= xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sTemperature, 'B5:B100');
                mfOverpotentialKinetic  	= xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sTemperature, 'C5:C100');
                mfCurrentDensityOhmic       = xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sTemperature, 'E5:E100');
                mfOverpotentialOhmic        = xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sTemperature, 'F5:F100');
                mfCurrentDensityMass        = xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sTemperature, 'H5:H100');
                mfOverpotentialMass         = xlsread('user\+examples\+ELY_FC\+ELY_Data\TestData.xlsx', sTemperature, 'I5:I100');
                
                scatter(mfCurrentDensityKinetic,    mfOverpotentialKinetic, 'MarkerEdgeColor', miPlotColor(iTemperature,:), 'Marker', 's')
                scatter(mfCurrentDensityOhmic,      mfOverpotentialOhmic,   'MarkerEdgeColor', miPlotColor(iTemperature,:), 'Marker', '>')
                scatter(mfCurrentDensityMass,       mfOverpotentialMass,    'MarkerEdgeColor', miPlotColor(iTemperature,:), 'Marker', 'o')
            end
            % We just add empty plots to better create a legend for this
            % plot
            h(iTemperature+1, 1) = plot(0, 0, 'Color', 'k', 'LineStyle', '-');
            h(iTemperature+1, 2) = plot(0, 0, 'Color', 'k', 'LineStyle', '--');
            h(iTemperature+1, 3) = plot(0, 0, 'Color', 'k', 'LineStyle', '-.');
            h(iTemperature+1, 4) = plot(0, 0, 'Color', 'k', 'LineStyle', ':');
            
            legend([h(1, 1), h(2, 1), h(3, 1), h(4, 1), h(5, 1), h(6, 1), h(6, 2), h(6, 3), h(6, 4)], '30 °C', '40 °C', '50 °C', '60 °C', '70 °C', 'Ohmic', 'Kinetic', 'Concentration', 'Mass Transport', 'Location','northwest')
            grid on
            xlabel('Current Density / A/cm^2');
            ylabel('Overpotential / V');
            xlim([0,4])
             
            
            %% V-HAB Plotting
            % In case it is of interest to plot the electrolyzer values
            % within the V-HAB framework, thix code can be reimplemented
%             oPlotter = plot@simulation.infrastructure(this);
%             coPlotsOhmic            = cell(length(oELY_FC.mfPressure), length(oELY_FC.mfTemperature));
%             coPlotsKinetic          = cell(length(oELY_FC.mfPressure), length(oELY_FC.mfTemperature));
%             coPlotsConcentration    = cell(length(oELY_FC.mfPressure), length(oELY_FC.mfTemperature));
%             for iPressure = 1:length(oELY_FC.mfPressure)
%                 for iTemperature = 1:length(oELY_FC.mfTemperature)
%                     sElectrolyzer = ['Electrolyzer_', num2str(oELY_FC.mfPressure(iPressure)), '_', num2str(oELY_FC.mfTemperature(iTemperature))];
%                     
%                     tPlotOptions = struct('sAlternativeXAxisValue', ['"', sElectrolyzer, ' Current"'], 'sXLabel', 'Current Density / A/cm^2', 'fTimeInterval', 300);
% 
%                     coPlotsOhmic{iPressure, iTemperature}           = oPlotter.definePlot({['"', sElectrolyzer, ' Ohmic Overpotential"']},        [sElectrolyzer, 'Ohmic Overpotential'],          tPlotOptions);
%                     coPlotsKinetic{iPressure, iTemperature}         = oPlotter.definePlot({['"', sElectrolyzer, ' Kinetic Overpotential"']},      [sElectrolyzer, 'Kinetic Overpotential'],      	 tPlotOptions);
%                     coPlotsConcentration{iPressure, iTemperature}   = oPlotter.definePlot({['"', sElectrolyzer, ' Concentration Overpotential"']},[sElectrolyzer, 'Concentration Overpotential'],  tPlotOptions);
%                     
%                 end
%             end
%             oPlotter.defineFigure(coPlotsOhmic,         'Electrolyzer Ohmic Overpotential');
%             oPlotter.defineFigure(coPlotsKinetic,       'Electrolyzer Kinetic Overpotential');
%             oPlotter.defineFigure(coPlotsConcentration, 'Electrolyzer Concentration Overpotential');
%             
%             oPlotter.plot();
        end
    end
end