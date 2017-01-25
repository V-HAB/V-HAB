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
        function this = setup(ptConfigParams, tSolverParams, bSimpleCDRA) % Constructor function
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            warning( 'off', 'all')
            
            this@simulation.infrastructure('Tutorial_CCAA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            if nargin < 3
                bSimpleCDRA = false;
            end
            % Creating the root object
            tutorials.CDRA.systems.Example(this.oSimulationContainer, 'Example', bSimpleCDRA);

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 50; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity', '-', 'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2');
            
            
            for iBed = 1:2
                for iCell = 1:5
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.CO2)', 'kg', ['Partial Mass CO2 Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.H2O)', 'kg', ['Partial Mass H2O Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                end
            end
            
            for iBed = 1:2
                for iCell = 1:5
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.CO2)', 'kg', ['Partial Mass CO2 Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.H2O)', 'kg', ['Partial Mass H2O Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                end
            end
            
            for iBed = 1:2
                for iCell = 1:5
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.CO2)', 'kg', ['Partial Mass CO2 Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.H2O)', 'kg', ['Partial Mass H2O Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                end
            end
            
            
            oLog.add('Example:c:CDRA', 'flow_props');
            
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('Pa',  'Tank Pressures');
            oPlot.definePlotAllWithFilter('K',   'Temperatures');
            oPlot.definePlotAllWithFilter('kg',  'Tank Masses');
            oPlot.definePlotAllWithFilter('kg/s','Flow Rates');
            
            
            csZeolite13x_CO2 = cell(2,5);
            csZeolite13x_H2O = cell(2,5);
            for iBed = 1:2
                for iCell = 1:5
                     csZeolite13x_CO2{iBed,iCell} = ['Partial Mass CO2 Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)];
                     csZeolite13x_H2O{iBed,iCell} = ['Partial Mass H2O Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)];
                end
            end
            
            csSylobead_CO2 = cell(2,5);
            csSylobead_H2O = cell(2,5);
            for iBed = 1:2
                for iCell = 1:5
                     csSylobead_CO2{iBed,iCell} = ['Partial Mass CO2 Sylobead_',num2str(iBed),' Cell ',num2str(iCell)];
                     csSylobead_H2O{iBed,iCell} = ['Partial Mass H2O Sylobead_',num2str(iBed),' Cell ',num2str(iCell)];
                end
            end
            
            csZeolite5A_CO2 = cell(2,5);
            csZeolite5A_H2O = cell(2,5);
            for iBed = 1:2
                for iCell = 1:5
                    csZeolite5A_CO2{iBed,iCell} = ['Partial Mass CO2 Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)];
                    csZeolite5A_H2O{iBed,iCell} = ['Partial Mass H2O Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)];
                end
            end
            
%             csCO2_Total = {csZeolite13x_CO2{1,:}, csZeolite13x_CO2{2,:}, csSylobead_CO2{1,:}, csSylobead_CO2{2,:}, csZeolite5A_CO2{1,:}, csZeolite5A_CO2{2,:}};
%             
%             csH2O_Total = {csZeolite13x_H2O{1,:}, csZeolite13x_H2O{2,:}, csSylobead_H2O{1,:}, csSylobead_H2O{2,:}, csZeolite5A_H2O{1,:}, csZeolite5A_H2O{2,:}};
            
            sTitle = 'Partial Mass CO2 CDRA'; 
            yLabel = 'Partial Mass CO2 in kg';
            
            mbPosition = [true,false;false,false;false,false];
            oPlot.definePlotByName(csSylobead_CO2(1,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,true;false,false;false,false];
            oPlot.definePlotByName(csSylobead_CO2(2,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,false;true,false;false,false];
            oPlot.definePlotByName(csZeolite13x_CO2(1,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,false;false,true;false,false];
            oPlot.definePlotByName(csZeolite13x_CO2(2,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,false;false,false;true,false];
            oPlot.definePlotByName(csZeolite5A_CO2(1,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,false;false,false;false,true];
            oPlot.definePlotByName(csZeolite5A_CO2(2,:), sTitle, yLabel, mbPosition);
            
            
            
            sTitle = 'Partial Mass H2O CDRA'; 
            yLabel = 'Partial Mass H2O in kg';
            
            mbPosition = [true,false;false,false;false,false];
            oPlot.definePlotByName(csSylobead_H2O(1,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,true;false,false;false,false];
            oPlot.definePlotByName(csSylobead_H2O(2,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,false;true,false;false,false];
            oPlot.definePlotByName(csZeolite13x_H2O(1,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,false;false,true;false,false];
            oPlot.definePlotByName(csZeolite13x_H2O(2,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,false;false,false;true,false];
            oPlot.definePlotByName(csZeolite5A_H2O(1,:), sTitle, yLabel, mbPosition);
            
            mbPosition = [false,false;false,false;false,true];
            oPlot.definePlotByName(csZeolite5A_H2O(2,:), sTitle, yLabel, mbPosition);
            
            
            csNames = {'Partial Pressure CO2'};
            sTitle = 'Partial Pressure CO2 Habitat'; 
            yLabel = 'Partial Pressure CO_2 in Pa';
            oPlot.definePlotByName(csNames, sTitle, yLabel);
            
            csNames = {'Relative Humidity Cabin'};
            sTitle = 'Relative Humidity Habitat'; 
            yLabel = 'Relative Humidity';
            oPlot.definePlotByName(csNames, sTitle, yLabel);
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
          
            this.toMonitors.oPlotter.plot();
            
            return
            
        end
    end
end