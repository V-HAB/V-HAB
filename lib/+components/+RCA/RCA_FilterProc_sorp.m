classdef RCA_FilterProc_sorp < components.filter.FilterProc_sorp
%RCA_FILTERPROC_SORP Filter processor inherits from the generic filter processor
%   Properties and post-processing for plots are added An if-line is added
%   to prevent unnecessary call of the inactive bed A function to reset the
%   internal timer is added. This function is activated once the RCA beds
%   switch

    
    properties
        
        % Needed for plotting
        % Loadings
        q_plot_H2O = zeros(1,3);    % loading of H2O
        q_plot_CO2 = zeros(1,3);    % loading of CO2
        q_plot_O2 = zeros(1,3);     % loading of O2 
        q_plot_N2 = zeros(1,3)      % loading of N2
        % Outlet values
        fC_CO2Out = 0;              % outlet concentration of CO2 in [Pa], [mmHg] or [ppm]
        rRH_in = 0;                 % relative humidity at the inlet [%]
        rRH_out = 0;                % relative humidity at the outlet [%]
        fDewPoint_in = 0;           % dew point temperature at the inlet [°F]
        fDewPoint_out = 0;          % dew point temperature at the outlet [°F]
        
    end
    
   
    
    methods
        
        % Initialization like in the generic filter processor
        function [this] = RCA_FilterProc_sorp(oParentSys, oStore, sName, sPhaseIn, sPhaseOut, sType)
            this@components.filter.FilterProc_sorp(oParentSys, oStore, sName, sPhaseIn, sPhaseOut, sType);   
        end
        
        function update(this)
                        
%             % Execute only for the active bed
%             if (strcmp(this.oStore.sName, 'Bed_A') && ~strcmp(this.oParentSys.sActiveBed, 'A')) || ...
%                (strcmp(this.oStore.sName, 'Bed_B') && ~strcmp(this.oParentSys.sActiveBed, 'B'))
%                 return;
%             end             
            
            update@components.filter.FilterProc_sorp(this)
            
            %% Post Processing
            % Save for plotting:
            if isempty(this.q_plot)
                return;
            end
            
            this.q_plot_H2O = zeros(3,1);
%             this.q_plot_H2O = q_plot(strcmp('H2O',this.csNames), :);
            this.q_plot_CO2 = this.q_plot(strcmp('CO2',this.csNames), :);
            this.q_plot_O2  = zeros(3,1);
            this.q_plot_O2  = this.q_plot(strcmp('O2',this.csNames), :);
%             this.q_plot_N2 = this.q_plot(strcmp('N2',this.csNames), :);    
            
            % To make the code more readable and reduce the number of
            % context changes, we initialize some local variables with the
            % indexes of CO2 and H2O in the matter table.
            iIndexCO2 = this.oMT.tiN2I.CO2;
            iIndexH2O = this.oMT.tiN2I.H2O;
            
            
            % Outlet concentration of CO2
            rMassFraction_CO2 = this.oStore.toPhases.FlowPhase.toProcsEXME.Outlet.oFlow.arPartialMass(iIndexCO2);
            
            % Calculation of outgoing concentration
            rMolFraction_CO2 = rMassFraction_CO2 * this.oStore.toPhases.FlowPhase.toProcsEXME.Outlet.oFlow.fMolarMass / this.oMT.afMolarMass(iIndexCO2); % mol fraction [-]
            this.fC_CO2Out   = rMolFraction_CO2 * this.fSorptionPressure / (matter.table.Const.fUniversalGas * this.fTemperature);          % [mol/m^3]
            this.fC_CO2Out   = this.fC_CO2Out * matter.table.Const.fUniversalGas * this.fTemperature * 7.5006e-3;                     % [mmHg]   
            
            % Calculate relative humitidy
            % Saturated vapor pressure
            fEw = 611.2 * exp((17.62 * (this.fTemperature - 273.15)) / (243.12 + this.fTemperature - 273.15));  %[Pa] 
            
            % gas constant for water
            fRw = 461.52;             %[J/(kg*K)]
            
            % Maximal humidity
            fDelta_sat = fEw / (fRw * this.fTemperature);
            
            % H2O concentration
            % Outlet concentration of H2O
            rMassFraction_H2O = this.oStore.toPhases.FlowPhase.toProcsEXME.Outlet.oFlow.arPartialMass(iIndexH2O);
            
            % Calculation of outgoing concentration
            rMolFraction_H2O = rMassFraction_H2O * this.oStore.toPhases.FlowPhase.toProcsEXME.Outlet.oFlow.fMolarMass / this.oMT.afMolarMass(iIndexH2O); % mol fraction [-]
            fC_H2O_Out       = rMolFraction_H2O * this.fSorptionPressure / (matter.table.Const.fUniversalGas * this.fTemperature);          % [mol/m^3]
            fC_H2O_In        = this.afConcentration(strcmp('H2O',this.csNames));
            
            % Relative Humidity of the gas flow
            this.rRH_out = fC_H2O_Out * this.oMT.afMolarMass(this.oMT.tiN2I.H2O) / fDelta_sat * 100;
            this.rRH_in  = fC_H2O_In  * this.oMT.afMolarMass(this.oMT.tiN2I.H2O) / fDelta_sat * 100; 
            
            % Calculate the dew point temperatures 
            % At the inlet
            fFactor_A         = (17.5043 * (this.fTemperature - 273.15)) / (241.2 + this.fTemperature - 273.15);
            this.fDewPoint_in = (241.2 * ( log(this.rRH_in) + fFactor_A) ) / (17.5043 - log(this.rRH_in) - fFactor_A);    % [°C]
            this.fDewPoint_in = this.fDewPoint_in * 1.8 + 32; % [°F]
            
            % At the outlet
            this.fDewPoint_out = (241.2 * ( log(this.rRH_out) + fFactor_A) ) / (17.5043 - log(this.rRH_out) - fFactor_A); % [°C]
            this.fDewPoint_out = this.fDewPoint_out * 1.8 + 32; % [°F]
            
            
        end
        % Desorption function after generic filter
        % Delete also the values for the plotting
        function desorption(this, rDesorptionRatio)
            desorption@components.filter.FilterProc_sorp(this, rDesorptionRatio)
            
            % Reset plotting values
            this.q_plot_H2O    = zeros(3,1);
            this.q_plot_O2     = zeros(3,1);
            this.q_plot_CO2    = zeros(3,1);
            this.rRH_in        = 0;
            this.fDewPoint_in  = 0;
            this.rRH_out       = 0;
            this.fDewPoint_out = 0;
            this.fC_CO2Out     = 0;

            % Set flow rates in the inactive bed to zero
            this.setMatterProperties(0, this.arPartials_ads);
            this.DesorptionProc.setMatterProperties(0, this.arPartials_des);
            
        end
        
        function reset_timer(this, fTime)
            % Set the timer for the new bed to the time of the bed switch
            % (as the new filterproc hasn't been called the values remained at the initial value)
            this.fLastExec            = fTime;
            this.fCurrentSorptionTime = fTime;
        end
        
    end
end
