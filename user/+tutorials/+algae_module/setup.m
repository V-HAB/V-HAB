classdef setup < simulation
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
        function this = setup() % Constructor function
            this@simulation('AlgaeModuleExample');
            
            % Creating the root object
            oExample = tutorials.algae_module.systems.AlgaeModuleExample(this.oRoot, 'AlgaeModuleExample');
            
            
            % Add branch to solver
            % oB1 = solver.matter.linear.branch(oExample.aoBranches(2));
            %oB1 = solver.matter.manual.branch(oExample.aoBranches(1));
            
            %solver.matter.manual.branch.fFlowRate     = 0.55;
            %oB1=solver.matter.manual.branch(oExample.aoBranches(1));
            %             solver.matter.manual.branch.bHighFlowRate = false;
            
            
            
            %oB2 = solver.matter.linear.branch(oExample.aoBranches(2));
            %% Ignore the contents of this section
            % Set a veeery high fixed time step - the solver will still be
            % called by the phase update methods!
            %             aoPhases = this.oRoot.toChildren.Example.toStores.Filter.aoPhases;
            %             aoPhases(1).bSynced = true;
            %             aoPhases = this.oRoot.toChildren.AlgaeModuleExample.toChildren.SubSystemColdplate.toStores.water_absorber.aoPhases;
            %             aoPhases(1).bSynced = true;
            %              aoPhases = this.oRoot.toChildren.AlgaeModuleExample.toStores.PotableWaterTank.aoPhases;
            %              aoPhases(1).fFixedTS = 0.5;
            %              aoPhases = this.oRoot.toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases;
            %              aoPhases(1).fFixedTS = 0.5;
            
            %% Logging
            % Creating a cell setting the log items
            this.csLog = {
                
            
            'oData.oTimer.fTime';  %1   % System timer
            'toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases(1).fPressure'; % crew module
            'toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases(1).fMass';
            'toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases(1).rRelHumidity';
            'toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases(1).afPP(11)';
            'toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases(1).afPP(7)';
            'toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases(1).afMass(11)';
            'toChildren.AlgaeModuleExample.toStores.crew_module.aoPhases(1).afMass(7)';
            'toChildren.AlgaeModuleExample.toStores.PotableWaterTank.aoPhases(1).fMass'; % potable water tank
            'toChildren.AlgaeModuleExample.toStores.PotableWaterTank.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.Food_Storage.aoPhases(1).fMass'; % Food Storage
            'toChildren.AlgaeModuleExample.toStores.Food_Storage.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.Inedible_Biomass.aoPhases(1).fMass'; % Inedible Biomass
            'toChildren.AlgaeModuleExample.toStores.Inedible_Biomass.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.N2_buffer_tank.aoPhases(1).fPressure';% N2 buffer tank
            'toChildren.AlgaeModuleExample.toStores.N2_buffer_tank.aoPhases(1).fMass';
            'toChildren.AlgaeModuleExample.toStores.N2_buffer_tank.aoPhases(1).rRelHumidity';
            'toChildren.AlgaeModuleExample.toStores.N2_buffer_tank.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.NutrientTank.aoPhases(1).fMass'; % NutrientTank
            'toChildren.AlgaeModuleExample.toStores.NutrientTank.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.InedibleBiomassH2O.aoPhases(1).fMass'; % InedibleBiomassH2O
            'toChildren.AlgaeModuleExample.toStores.InedibleBiomassH2O.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.InedibleBiomassH2O.aoPhases(1).afMass(18)';
            'toChildren.AlgaeModuleExample.toStores.InedibleBiomassH2O.aoPhases(1).afMass(10)';
            'toChildren.AlgaeModuleExample.toStores.HygieneWaterTank.aoPhases(1).fMass'; % HygieneWaterTank
            'toChildren.AlgaeModuleExample.toStores.HygieneWaterTank.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.H2O2Tank.aoPhases(1).fMass'; % H2O2Tank
            'toChildren.AlgaeModuleExample.toStores.H2O2Tank.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toStores.Deadlock.aoPhases(1).fMass'; % Deadlock
            'toChildren.AlgaeModuleExample.toStores.Deadlock.aoPhases(1).fTemp';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(1).fMass';% algae modul log
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(2).fMass';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(3).fMass';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(1).fPressure';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(2).fPressure';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(3).fPressure'
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.aoBranches(1).fFlowRate';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.aoBranches(2).fFlowRate';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.aoBranches(3).fFlowRate';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.aoBranches(4).fFlowRate';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.aoBranches(5).fFlowRate';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.oProc_Absorber_Algae.fFlowRate';% Flowphase -> Algae
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.oProc_Absorber_Algae2.fFlowRate'; %CO2
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.oProc_Absorber_O2.fFlowRate';%O2
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.fAerationPower';
             'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.oProc_Absorber_Algae.fProductivity';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.oProc_Absorber_Algae.fDilution';
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(2).afMass(7)';%O2
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(2).afMass(11)';%CO2
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(2).afMass(13)';%NO3
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toStores.FilterAlgaeReactor.aoPhases(2).afMass(16)';%Spirulina
            'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.oProc_Absorber_Algae.fPower';
            %             'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toChildren.TemperatureControl_and_Illumination.fP_harv';
            %             'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toChildren.TemperatureControl_and_Illumination.fP_fill';
            %             'toChildren.AlgaeModuleExample.toChildren.SubSystemAlgaeModule.toChildren.TemperatureControl_and_Illumination.fQ_out';
           
            
            
            };
        
        %% Simulation length
        % Stop when specific time in sim is reached
        % or after specific amount of ticks (bUseTime true/false).
        this.fSimTime = 3600*100; % In seconds
        this.iSimTicks = 1000;
        
        this.bUseTime = true;
        
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            
            close all
            %             figure('name', 'Realtive Humidity in Crew Module');
            %             axes1 = axes('Parent',figure1,'FontSize',14);
            %             hold(axes1,'all');
            % %             hold on;
            %             %grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:,4)*100, 'Parent',axes1,'LineWidth',2,...
            %     'DisplayName','relative humidity in Crew Module');
            %             legend('relative humidity in Crew Module');
            %             ylabel('realtive humidity[%]','FontSize',14);
            %             xlabel('Time in s','FontSize',14);
            
            % Create figure
            % Create figure
            figure1 = figure('Name','Results of the AlgaeModulTest','Color',[1 1 1]);
            
            % Create subplot
            subplot1 = subplot(2,2,1,'Parent',figure1,'YGrid','on','XGrid','on',...
                'FontSize',12);
            box(subplot1,'on');
            hold(subplot1,'all');
            
            % Create plot
            plot2=plot(this.mfLog(:,1)/3600, this.mfLog(:,[9]),'Parent',subplot1,'LineWidth',2);
            set(plot2(1),'DisplayName','O2 Mass Crew Module [kg]');
            %             set(plot2(2),'DisplayName','Mass H2O2Tank [kg]');
            %             set(plot2(3),'DisplayName','Mass Inedible Biomass [kg]');
            legend(subplot1,'show');
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Mass [kg]','FontSize',12);
            
            % Create title
            %title('Mass','FontSize',12);
            
            % Create subplot
            subplot2 = subplot(2,2,2,'Parent',figure1,'YGrid','on','XGrid','on',...
                'FontSize',12);
            box(subplot2,'on');
            hold(subplot2,'all');
            
            % Create plot
            plot4= plot(this.mfLog(:,1)/3600, abs(this.mfLog(:,[8])),'Parent',subplot2,'LineWidth',2);
            set(plot4(1),'DisplayName','CO2 Mass Crew Module [kg]');
            %             set(plot4(2),'DisplayName','Flow rate air out (O1)');
            %             set(plot4(3),'DisplayName','Flow rate H2O in (I2)');
            %             set(plot4(4),'DisplayName','Flow rate H2O2 out (O2)');
            legend(subplot2,'show');
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Mass [kg]','FontSize',12);
            
            % Create title
            %title('Relative humidity[%]','FontSize',12);
            
            % Create subplot
            subplot3 = subplot(2,2,3,'Parent',figure1,'YGrid','on','XGrid','on',...
                'FontSize',12);
            box(subplot3,'on');
            hold(subplot3,'all');
            
            % Create plot
            plot5= plot(this.mfLog(:,1)/3600, abs(this.mfLog(:,[38,42])),'Parent',subplot3,'LineWidth',2);
            set(plot5(1),'DisplayName','Flow rate air in (I1)');
            set(plot5(2),'DisplayName','Flow rate air out (O1)');
            
            
            
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Flow rate [kg/s]','FontSize',12);
            
            % Create title
            %title('Mass CO2 [kg]','FontSize',12);
            
            % Create subplot
            subplot5 = subplot(2,2,4,'Parent',figure1,'YGrid','on','XGrid','on',...
                'FontSize',12);
            box(subplot5,'on');
            hold(subplot5,'all');
            
            % Create plot
            plot6= plot(this.mfLog(:,1)/3600, abs(this.mfLog(:,[39,40,41])),'Parent',subplot5,'LineWidth',2);
            set(plot6(1),'DisplayName','Flow rate NO3 in (I2)');
            set(plot6(2),'DisplayName','Flow rate Food out (O3)');
            set(plot6(3),'DisplayName','Flow rate Inedible Biomass out (O2)');
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Flow rate [kg/s]','FontSize',12);
            
            % Create title
            %title('Mass O2 [kg]','FontSize',12);
            
            % Create legend
            legend(subplot1,'show');
            
            % Create legend
            legend1 = legend(subplot2,'show');
            set(legend1,...
                'Position',[0.694909344490934 0.869269949066214 0.20397489539749 0.043010752688172]);
            
            % Create legend
            legend(subplot3,'show');
            
            % Create legend
            legend(subplot5,'show');
            %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %             % Create figure
            
            figure2 = figure('PaperSize',[20.98404194812 29.67743169791],...
                'Name','HumanDummyValues',...
                'Color',[1 1 1]);
            
            % Create axes
            axes1 = axes('Parent',figure2,'YGrid','on','XGrid','on',...
                'Position',[0.13 0.557755775577558 0.34907949790795 0.367244224422443],...
                'FontSize',12);
            box(axes1,'on');
            hold(axes1,'all');
            
            % Create plot
            plot8=plot(this.mfLog(:,1)/3600,this.mfLog(:,[47]),'Parent',axes1,'LineWidth',2);
            set(plot8(1),'DisplayName','Productivity [mg/(l*h)]');
%             set(plot8(2),'DisplayName','FoodStorage Mass [kg]');
%             set(plot8(3),'DisplayName','InedibleBiomass+H2O Mass [kg]');
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Mass [kg]','FontSize',12);
            
            % Create axes
            axes2 = axes('Parent',figure2,'YGrid','on','XGrid','on',...
                'Position',[0.560669456066946 0.552805280528053 0.342069703309242 0.372194719471948],...
                'FontSize',12);
            box(axes2,'on');
            hold(axes2,'all');
            
            % Create plot
            plot9=plot(this.mfLog(:,1)/3600, abs(this.mfLog(:,[48])),'Parent',axes2,'LineWidth',2,'DisplayName','InedibleBiomass+H2O Mass[kg]');
            set(plot9(1),'DisplayName','Dilution [g/l]');

            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Dilution [g/l]','FontSize',12);
            
            % Create axes
            axes3 = axes('Parent',figure2,'YGrid','on','XGrid','on',...
                'Position',[0.13 0.11 0.345941422594142 0.363597359735974],...
                'FontSize',12);
            box(axes3,'on');
            hold(axes3,'all');
            
            % Create plot
            plot11 =plot(this.mfLog(:,1)/3600, abs(this.mfLog(:,[43 44 45])),'Parent',axes3,'LineWidth',2);
            set(plot11(1),'DisplayName','Flow rate FLowphase -> Spirulina ');
            set(plot11(2),'DisplayName','Flow rate Aeration -> Flowphase CO2');
            set(plot11(3),'DisplayName','Flow rate Spirulina -> Aeration O2');
            
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Flow rate[kg/s]','FontSize',12);
            
            % Create axes
            axes4 = axes('Parent',figure2,'YGrid','on','XGrid','on',...
                'Position',[0.560669456066946 0.11 0.342069703309241 0.356996699669967],...
                'FontSize',12);
            box(axes4,'on');
            hold(axes4,'all');
            
            % Create plot
            plot13=plot(this.mfLog(:,48), this.mfLog(:,47),'Parent',axes4,'LineWidth',2,'DisplayName','Flow rate[kg/s]');
            set(plot13(1),'DisplayName','Productivity[mg/(l*h)]');
         
            
            % Create xlabel
            xlabel('Dilution[g/l]','FontSize',12);
            
            % Create ylabel
            ylabel('Productivity [mg/(l*h)]','FontSize',12);
            
            % Create legend
            legend(axes1,'show');
            
            % Create legend
            legend1 = legend(axes2,'show');
            set(legend1,...
                'Position',[0.768131101813102 0.878124060283787 0.126569037656904 0.0418041804180418]);
            %
            % Create legend
            legend(axes3,'show');
            
            % Create legend
            legend(axes4,'show');
            
            
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %             % Create figure
            
            figure3 = figure('PaperSize',[20.98404194812 29.67743169791],...
                'Name','HumanDummyValues',...
                'Color',[1 1 1]);
            
            % Create axes
            axes1 = axes('Parent',figure3,'YGrid','on','XGrid','on',...
                'Position',[0.13 0.557755775577558 0.34907949790795 0.367244224422443],...
                'FontSize',12);
            box(axes1,'on');
            hold(axes1,'all');
            
            % Create plot
            plot8=plot(this.mfLog(:,1)/3600,this.mfLog(:,[52]),'Parent',axes1,'LineWidth',2);
            set(plot8(1),'DisplayName','Mass Algae [kg]');
%             set(plot8(2),'DisplayName','FoodStorage Mass [kg]');
%             set(plot8(3),'DisplayName','InedibleBiomass+H2O Mass [kg]');
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Mass [kg]','FontSize',12);
            
            % Create axes
            axes2 = axes('Parent',figure3,'YGrid','on','XGrid','on',...
                'Position',[0.560669456066946 0.552805280528053 0.342069703309242 0.372194719471948],...
                'FontSize',12);
            box(axes2,'on');
            hold(axes2,'all');
            
            % Create plot
            plot9=plot(this.mfLog(:,1)/3600, abs(this.mfLog(:,[6])),'Parent',axes2,'LineWidth',2,'DisplayName','InedibleBiomass+H2O Mass[kg]');
            set(plot9(1),'DisplayName','Crew Module CO2 partial pressure');

            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Pressure [Pa]','FontSize',12);
            
            % Create axes
            axes3 = axes('Parent',figure3,'YGrid','on','XGrid','on',...
                'Position',[0.13 0.11 0.345941422594142 0.363597359735974],...
                'FontSize',12);
            box(axes3,'on');
            hold(axes3,'all');
            
            % Create plot
            plot11 =plot(this.mfLog(:,1)/3600, abs(this.mfLog(:,[12 14])),'Parent',axes3,'LineWidth',2);
            set(plot11(1),'DisplayName','Mass FoodStorage [kg] ');
            set(plot11(2),'DisplayName','Mass InedibleBiomass [kg]');
           
            
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Mass[kg]','FontSize',12);
            
            % Create axes
            axes4 = axes('Parent',figure3,'YGrid','on','XGrid','on',...
                'Position',[0.560669456066946 0.11 0.342069703309241 0.356996699669967],...
                'FontSize',12);
            box(axes4,'on');
            hold(axes4,'all');
            
            % Create plot
            plot13=plot(this.mfLog(:,1)/3600, this.mfLog(:,53),'Parent',axes4,'LineWidth',2,'DisplayName','Flow rate[kg/s]');
            set(plot13(1),'DisplayName','Power[W]');
         
            
            % Create xlabel
            xlabel('time[h]','FontSize',12);
            
            % Create ylabel
            ylabel('Power[W]','FontSize',12);
            
            % Create legend
            legend(axes1,'show');
            
            % Create legend
            legend1 = legend(axes2,'show');
            set(legend1,...
                'Position',[0.768131101813102 0.878124060283787 0.126569037656904 0.0418041804180418]);
            %
            % Create legend
            legend(axes3,'show');
            
            % Create legend
            legend(axes4,'show');
            
            
            %             figure('name', 'Tank Masses');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [3 7 14]));
            %             legend('crew module','Potable Water Tank','N2 Buffer Tank');
            %             ylabel('Mass in kg');
            %             xlabel('Time in s');
            %
            %             figure('name', 'Rel Humidity');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [4]));
            %             legend('crew module');
            %             ylabel('Rel Humidity');
            %             xlabel('Time in s');
            %
            %             figure('name', 'Flow Rate');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [9 10 11 12]));
            %             legend('crew module air in coldplate','crew module air out coldplate','coldplate H2O out to Potable Water Tank', 'P2P Coldplate'  );
            %             ylabel('flow rate [kg/s]');
            %             xlabel('Time in s');
            %
            %
            %
            %             figure('name', 'Tank Temperatures');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [5 8]));
            %             legend('crew module','Potable Water Tank');
            %             ylabel('Temperature in K');
            %             xlabel('Time in s');
            %
            %             figure('name', 'Time Steps');
            %             hold on;
            %             grid minor;
            %             plot(1:length(this.mfLog(:,1)), this.mfLog(:, 1), '-*');
            %             legend('Solver');
            %             ylabel('Time in [s]');
            %             xlabel('Ticks');
            %
            %             %Plots for algae subsystem:
            %             %             figure('name', 'Algae Mass');
            %             %             hold on;
            %             %             grid minor;
            %             %             plot(this.mfLog(:,1)/3600, this.mfLog(:,[74]));
            %             %             legend('Algae Mass');
            %             %             ylabel('Mass [kg]');
            %             %             xlabel('Time [s]');
            %
            %             %             figure('name', 'Dilution');
            %             %             hold on;
            %             %             grid minor;
            %             %             plot(this.mfLog(:,1)/3600, this.mfLog(:,95));
            %
            %             %             ylabel('Algae Mass');
            %             %             xlabel('Time [s]');
            %             %             figure('name', '2400 W');
            %             %             hold on;
            %             %             grid minor;
            %             %             plot(this.mfLog(:,82+index), this.mfLog(:,81+index));
            %
            %             ylabel('Productivity [mg/l/h]');
            %             xlabel('Cell Densitiy [g/l]');
            %
            %             figure('name', 'Compound conversion');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [41]));
            %             legend('CO2');
            %             ylabel('Mass [kg]');
            %             xlabel('Time [s]');
            %
            %             %
            %             %             figure('name', '2400 W');
            %             %             hold on;
            %             %             grid minor;
            %             %             plot(this.mfLog(:,1)/3600, this.mfLog(:, 94));
            %             %
            %             %             ylabel('Productivity [mg/l/h]');
            %             %             xlabel('Time in s');
            %
            %             %             figure('name', '2400 W');
            %             %             hold on;
            %             %             grid minor;
            %             %             plot(this.mfLog(:,1)/3600, this.mfLog(:,[83+index,84+index,55+index]));
            %             %             legend('CO2', 'NO3', 'O2');
            %             %             ylabel('Mass [kg]');
            %             %             xlabel('Time in s');
            %             %
            %             figure('name', 'Flow Rate Algae Modul-Crew Module');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [28 32]));
            %             legend('air in', 'air out'  );
            %             ylabel('flow rate [kg/s]');
            %             xlabel('Time in s');
            %
            %             figure('name', 'Flow Rates Algae Module');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [28:1:36]));
            %             %legend('air in', 'air out'  );
            %             ylabel('flow rate [kg/s]');
            %             xlabel('Time in s');
            %
            %             %             figure('name', 'Masses');
            %             %             hold on;
            %             %             grid minor;
            %             %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [66:1:75]));
            %             %             %legend('crew module','N2 Buffer Tank');
            %             %             ylabel('Mass in kg');
            %             %             xlabel('Time in s');
            %
            %             figure('name', 'Crew Module Partial Masses');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [60 61 62]));
            %             legend('O2','CO2','N2');
            %             ylabel('Mass in kg');
            %             xlabel('Time in s');
            %
            %             figure('name', 'Flow Rates Filter');
            %             hold on;
            %             grid minor;
            %             plot(this.mfLog(:,1)/3600, this.mfLog(:, [63 64 65]));
            %             legend('flowphase-algae[CO2]', 'aeration-flowphase[CO2]', 'algae-aeration[O2]'  );
            %             ylabel('flow rate [kg/s]');
            %             xlabel('Time in s');
        end
        
    end
    
end

