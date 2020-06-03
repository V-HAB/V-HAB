classdef CHX < vsys
%% Condensing Heat Exchanger Model
% With this component it is possible to calculate the outlet temperatures 
% and pressure drops of different heat exchangers as well as the generated
% condensate mass flow
%
% Fluid 1, FlowProc 1 is the one with the fluid flowing through the pipes
% if there are any pipes.
%
% The component uses the following user inputs:
%
%% sHX_type 
% with information about what type of heat exchanger should be calculated.
% Other types (like the ones available as HX) must be derived from the
% existing program. But the implemented type of CHX is the one also used on
% the ISS and the type which is commonly used in life support systems. The
% possible inputs as strings are currently:
%           'plate_fin'
%
%% iIncrements:
% which decides into how many subsections the heat exchanger will be split
% in order to calculate the condensation. The more subsection are used the
% more accurate the model gets but the computation time will increase
% rapidly as well because the heat exchanger has to be calculated as often
% as this number. (especially for cross flow heat exchangers with mutliple
% pipe rows because the number of increments is multiplied with the number
% of pipe rows)
%
%% tCHX_Parameters
% The struct tCHX_Parameters contains the information about the geometry of
% the heat exchanger and therefore depends on the type of CHX used.
% For plate_fin:
%             % broadness of the heat exchange area in m
%             tGeometry.fBroadness        = 0.1;  
%             % Height of the channel for fluid 1 in m
%             tGeometry.fHeight_1         = 0.003;
%             % Height of the channel for fluid 2 in m
%             tGeometry.fHeight_2         = 0.003;
%             % length of the heat exchanger in m
%             tGeometry.fLength           = 0.1;
%             % thickness of the plate in m
%             tGeometry.fThickness        = 0.004;
%             % number of layers stacked
%             tGeometry.iLayers           = 33;
%             % number of baffles (evenly distributed)
%             tGeometry.iBaffles          = 3;
%             % broadness of a fin of the first canal (air)
%             tGeometry.fFinBroadness_1	= 1/18;
%             % broadness of a fin of the second canal (coolant)
%             tGeometry.fFinBroadness_2	= 1/18; 
%             %  Thickness of the Fins (for now both fins have the same thickness
%             tGeometry.fFinThickness     = 0.001;
%
%% Optional Inputs:
%% fThermalConductivityHeatExchangerMaterial
% the thermal conductivity of the heat exchanger material in W/(m K) (if
% not provided it is assumed to be infinite)
%
%% fTempChangeToRecalc
% The allowed temperature change in any inflow before the CHX is
% recalculated in K. Base value is 0.5 K
%
%% fPercentChangeToRecalc
% the allowed percentage change in the in flow compositions in [-] (so a
% value between 0 and 1) before recalculation. Base value is 0.05
%
%% Example
% please go to user/+examples/condensing_heat_exchanger/+systems/Example.m
% for an example on how to implement the CHX in a V-HAB system
%
%% Notes:
% Please note that the calculated dew point can be lower than the dew point
% in the cabin phase, if the pressure in the CHX is higher than in the
% cabin because of F2Fs procs! That is actually not an error in the code,
% but a realistic result of the higher total gas pressure in the CHX.

    properties 
        % flow to flow processors for fluid 1 and 2 to set outlet temp and
        % pressure
        oF2F_1; 
        oF2F_2;
        
        % User Inputs for the geometry of the heat exchanger
        tCHX_Parameters;
        
        % User input for the type of heat exchanger (see hx_man for more
        % information)
        sCHX_type;
        
        % Outlet temperatures of the heat exchangers. These two variables
        % don't directly serve any purpose but can be used to plot the
        % outlet temperature directly behind the heat exchanger
        fTempOut_Fluid1 = 0;
        fTempOut_Fluid2 = 0;
        
        % Old Values for the previous iteration which are used to check if
        % anything should be recalculated
        fEntryTemp_Old_1 = 0;
        fEntryTemp_Old_2 = 0;
        fMassFlow_Old_1 = 0;
        fMassFlow_Old_2 = 0;
        arPartialMass1Old = 0;
        arPartialMass2Old = 0;
        fOldPressureFlow1 = 0;
        fOldPressureFlow2 = 0;
        
        % variable to check wether it is the first iteration step
        iFirst_Iteration = int8(1);
        
        % Replace the following with the heat exchanger material, the
        % conductivity can then be gathered from the matter table. 
        fThermalConductivityHeatExchangerMaterial = Inf;    %Heat exchanger material thermal conductivity
        % initialized to infinite because in this case there is no thermal
        % resistance from conductance
        
        % vector containing the phase change enthalpy for the different
        % substances.
        mPhaseChangeEnthalpy = 0;
        
        % Vector containing the overall condensate mass flow for all
        % substances
        afCondensateMassFlow;
        
        % number of incremental heat exchangers that have to be calculated
        iIncrements = 1;
        
        % Last execution time of the CHX
        fLastExecution = 0; 
        
        % Overall heat flow for the latent heat (phase change energy)
        fTotalCondensateHeatFlow = 0;
        
        % Overall heat flow (sum of latent and sensible heat, so phase
        % change energy and temperature difference combined)
        fTotalHeatFlow = 0;
        
        % Reference to the phase to phase processor which performs the
        % actual phase change of the condensate
        oP2P;
        
        % Here the user can specify by how much [K] the temperature has to
        % change before the CHX is recalculated
        fTempChangeToRecalc = 0.5;
        
        % This value decides how much any value (composition of air,
        % pressure, etc.) has to change in percent before the CHX is
        % recalculated
        fPercentChangeToRecalc = 0.05;
    end
    
    methods
        function this = CHX(oParent, sName, tCHX_Parameters, sCHX_type, iIncrements, fThermalConductivityHeatExchangerMaterial, fTempChangeToRecalc, fPercentChangeToRecalc)
            this@vsys(oParent, sName, 60);
            
            %if a thermal conductivity for the heat exchanger is provided
            %it overrides the infinte value with which it is initialised
            if nargin > 5
                this.fThermalConductivityHeatExchangerMaterial = fThermalConductivityHeatExchangerMaterial;
            end
          
            this.tCHX_Parameters = tCHX_Parameters;
            this.sCHX_type = sCHX_type;      
            this.iIncrements = iIncrements;
            
            if nargin > 6
                this.fTempChangeToRecalc = fTempChangeToRecalc;
                this.fPercentChangeToRecalc = fPercentChangeToRecalc;
            end
            
            %values for phase change enthalpy from http://webbook.nist.gov
            %with molar mass from matter table (just not crosslinked) The
            %index is also from the matter table
            this.mPhaseChangeEnthalpy = zeros(1, this.oMT.iSubstances);
            %H2O
            this.mPhaseChangeEnthalpy(this.oMT.tiN2I.H2O) = 40650*(1/0.018015275); %J/kg
            %CO2
            this.mPhaseChangeEnthalpy(this.oMT.tiN2I.CO2) = 16500*(1/0.0440098); %J/kg
            %CH4
            this.mPhaseChangeEnthalpy(this.oMT.tiN2I.CH4) = 8600*(1/0.0160425); %J/kg
            
            %%
            %Possible trace contaminants
            %CO
            this.mPhaseChangeEnthalpy(this.oMT.tiN2I.CO) = 6000*(1/0.0280101); %J/kg
            
            %Nitrogen (N2)
            this.mPhaseChangeEnthalpy(this.oMT.tiN2I.N2) = 6100*(1/0.0280134); %J/kg
            
            %Ammonia (NH3)
            this.mPhaseChangeEnthalpy(this.oMT.tiN2I.NH3) = 22700*(1/0.0170305); %J/kg
            
            %Methane (CH4)
            this.mPhaseChangeEnthalpy(this.oMT.tiN2I.CH4) = 8500*(1/0.0160425); %J/kg
            
            % Initiliaze the condensate mass flows to zero:
            this.afCondensateMassFlow = zeros(1, this.oMT.iSubstances);
            
            %Because the HX f2f proc is actually added to the parent system
            %of the HX its definition has to take place here instead of the
            %createMatterStructure function
            
            %adds the flow to flow processores used to set the outlet
            %values of the heat exchanger
            this.oF2F_1 = components.matter.HX.hx_flow(this, this.oParent, [sName,'_1']);
            this.oF2F_2 = components.matter.HX.hx_flow(this, this.oParent, [sName,'_2']);
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
        end
        
        
        
        function ThermalUpdate(this)
            this.update();
        end
        function update(this)
            
            % We skip the very first update because some of the flow rates
            % are still zero. It is not allowed to stop the update even if
            % the update is called several times within the same time step
            % since that might be necessary to accomodate flow rate changes
            % within one time step!
            if this.oTimer.iTick == 0
                return;
            end
            
            % getInFlow() will produce an error if the flow rate is zero.
            % To avoid this, we try to do it "right", if it doesn't work,
            % we'll just take the fist flow. 
            try
                oFlows_1 = this.oF2F_1.getInFlow(); 
            catch
                oFlows_1 = this.oF2F_1.aoFlows(1);
            end
            
            try
                oFlows_2 = this.oF2F_2.getInFlow(); 
            catch
                oFlows_2 = this.oF2F_2.aoFlows(1);
            end
            
            %gets the values from the flows required for the HX
            fMassFlow_1 = abs(oFlows_1.fFlowRate);
            fMassFlow_2 = abs(oFlows_2.fFlowRate);
            fEntryTemp_1 = oFlows_1.fTemperature;
            fEntryTemp_2 = oFlows_2.fTemperature;
            
            %If nothing flows on one side of the HX it just assumes that
            %nothing happens
            if (fMassFlow_1 == 0) || (fMassFlow_2 == 0)
                
                this.oF2F_1.setOutFlow(0,0);
                this.oF2F_2.setOutFlow(0,0);
                
                this.afCondensateMassFlow = zeros(1, this.oMT.iSubstances);

                this.oP2P.update();
                return
            end
            
            %if query to see if the CHX has to be recalculated
            if  this.iFirst_Iteration == 1 ||...                                                                    %if it is the first iteration
                (abs(fEntryTemp_1-this.fEntryTemp_Old_1) > this.fTempChangeToRecalc) ||...                          %if entry temp changed by more than X�
                (abs(1-(fMassFlow_1/this.fMassFlow_Old_1)) > this.fPercentChangeToRecalc) ||...                 	%if mass flow changes by more than X%
                (abs(fEntryTemp_2-this.fEntryTemp_Old_2) > this.fTempChangeToRecalc)||...                           %if entry temp changed by more than X�
                (abs(1-(fMassFlow_2/this.fMassFlow_Old_2)) > this.fPercentChangeToRecalc)||...                      %if mass flow changes by more than X%
                (max(abs(1-(oFlows_1.arPartialMass./this.arPartialMass1Old))) > this.fPercentChangeToRecalc)||...  	%if composition of mass flow changed by more than X%
                (max(abs(1-(oFlows_2.arPartialMass./this.arPartialMass2Old))) > this.fPercentChangeToRecalc)||...   %if composition of mass flow changed by more than X%
                (abs(1-(oFlows_1.fPressure/this.fOldPressureFlow1)) > this.fPercentChangeToRecalc)||...             %if Pressure changed by more than X%
                (abs(1-(oFlows_2.fPressure/this.fOldPressureFlow2)) > this.fPercentChangeToRecalc)                  %if Pressure changed by more than X%
                            
                fDensity_1 = oFlows_1.getDensity();
                fDensity_2 = oFlows_2.getDensity();
                
                fCp_1 = oFlows_1.fSpecificHeatCapacity;
                fCp_2 = oFlows_2.fSpecificHeatCapacity;
                
                fDynVisc_1 = oFlows_1.getDynamicViscosity();
                fConductivity_1 = oFlows_1.oMT.calculateThermalConductivity(oFlows_1);
                
                fDynVisc_2 = oFlows_2.getDynamicViscosity();
                fConductivity_2 = oFlows_1.oMT.calculateThermalConductivity(oFlows_2);
            
                %sets the structs for the two fluids according to the
                %definition from HX_main
                Fluid_1 = struct();
                Fluid_1.fMassflow                = fMassFlow_1;
                Fluid_1.fEntry_Temperature       = fEntryTemp_1;
                Fluid_1.fDynamic_Viscosity       = fDynVisc_1;
                Fluid_1.fDensity                 = fDensity_1;
                Fluid_1.fThermal_Conductivity    = fConductivity_1;
                Fluid_1.fSpecificHeatCapacity    = fCp_1;
                Fluid_1.oFlow                    = oFlows_1;

                
                Fluid_2 = struct();
                Fluid_2.fMassflow                = fMassFlow_2;
                Fluid_2.fEntry_Temperature       = fEntryTemp_2;
                Fluid_2.fDynamic_Viscosity       = fDynVisc_2;
                Fluid_2.fDensity                 = fDensity_2;
                Fluid_2.fThermal_Conductivity    = fConductivity_2;
                Fluid_2.fSpecificHeatCapacity    = fCp_2;
                Fluid_2.oFlow                    = oFlows_2;

                
                %function call for HX_main to get outlet values
                % as first value the this struct from object HX is given to
                % the function HX_main
                [fTempOut_1, fTempOut_2, fDeltaPress_1, fDeltaPress_2] =...
                    this.(this.sCHX_type)(this.tCHX_Parameters, Fluid_1, Fluid_2, this.fThermalConductivityHeatExchangerMaterial, this.iIncrements);        

                %sets the outlet temperatures into the respective variable
                %inside the heat exchanger object for plotting purposes
                this.fTempOut_Fluid1 = fTempOut_1;
                this.fTempOut_Fluid2 = fTempOut_2;
                
                %Assignes the values of this iteration step as the old values
                %for the next step
                this.fEntryTemp_Old_1    = fEntryTemp_1;
                this.fEntryTemp_Old_2    = fEntryTemp_2;
                this.fMassFlow_Old_1     = fMassFlow_1;
                this.fMassFlow_Old_2     = fMassFlow_2;
                this.arPartialMass1Old   = oFlows_1.arPartialMass;
                this.arPartialMass2Old   = oFlows_2.arPartialMass;
                this.fOldPressureFlow1   = oFlows_1.fPressure;
                this.fOldPressureFlow2   = oFlows_2.fPressure;
                
                % Calculating the heat flows for both hx_flow objects
                fHeatFlow_1 = fMassFlow_1 * fCp_1 * (fTempOut_1 - fEntryTemp_1);
                fHeatFlow_2 = fMassFlow_2 * fCp_2 * (fTempOut_2 - fEntryTemp_2);
                
                % uses the function defined in flowcomps.hx_flow to set the
                % outlet values
                this.oF2F_1.setOutFlow(fHeatFlow_1, fDeltaPress_1);
                this.oF2F_2.setOutFlow(fHeatFlow_2, fDeltaPress_2);

                %sets the variable to decide wether it is the first
                %iteration step to zero
                if this.iFirst_Iteration == 1
                    this.iFirst_Iteration = int8(0);
                end
                %tells the ascociated p2p proc to update
                try
                    this.oP2P.calculateFlowRate();
                catch oErr
                    %the condensing heat exchanger requires a CHX_p2p proc
                    %to work properly. Otherwise it will calculate the
                    %phase change but it would not actually happen. To add
                    %the p2p proc correctly add it as object to your CHX
                    %object. So if you define the CHX like this in your sytem:
                    %
                    %oCHX = components.matter.CHX(this, 'HeatExchanger',...
                    %    Geometry, sHX_type, iIncrements, Conductivity);
                    %
                    %you can use the oCHX object variable to set the oP2P
                    %property of it later on. (Because the p2p proc also
                    %needs the CHX object as input it is not possible to
                    %add the p2p proc directly at the definition of the
                    %CHX)
                    %
                    %Then you can add the p2p proc while you define it by
                    %setting:
                    %oCHX.oP2P =  components.matter.HX.CHX_p2p(oStore,...
                    %                   sName, sPhaseIn, sPhaseOut, oCHX)
                    if isempty(this.oP2P)
                        error('the CHX only works with an additional CHX_p2p proc that should be set as property for the CHX (see comment at this error for more information)')
                    else
                        rethrow(oErr)
                    end
                end
                this.fLastExecution = this.oTimer.fTime;
            end
        end
    end
end


