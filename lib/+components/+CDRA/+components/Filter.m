classdef Filter < matter.procs.p2ps.flow

    %This phase to phase proc can be used as either a zeolith 13x filter to
    %remove humidity or a zeolith 5A filter that removes CO2. For the
    %zeolith 5A filter the capacity given is assumed to be valid for 400Pa
    %of CO2 in the atmosphere and 20°C since the capacity changes depending
    %on temperature and CO2 partial pressure. For the zeolite 13x filter
    %the capacity is asummed to be constant (you can add the isotherm for
    %it if you want)
    %While this proc is adaptable so that it can be used for different
    %filters the numbers are optimized for the ISS CDRA zeolite beds and
    %there is no guarantee that they will match all other zeolite filters
    %as well.
    %For the adsorption efficiency it uses a curve fitting command that
    %REQUIRES THE CURVE FITTING TOOLBOX to calculate a function for the
    %efficiency over the percent of adsorbed mass with regard to capacity.
    
    properties (SetAccess = protected, GetAccess = public)
        sSpecies;                       % Species to absorb
        fCapacity;                      % Max absorb capacity in kg
        arExtractPartials;              % Defines which species are extracted
        mfZeolithCapacity;              % Defines the capacity of the zeolith per mass of zeolith
        sFilterMode;                    % Defines wheter the filter absorbs oder desorbs
        fFlowRateFilter = 0;            % Flow rate of the matter, which gets filtered
        sType;
        
        %Heat flow at the zeolite (from the electrical heaters)
        fHeatFlow = 0;
        % adsorber f2f proc that calculates the heat flow between the
        % zeolite and the gas flow
        oF2F;
        
        %Interpolation for the capacity with regard to partial pressure and
        %temperature
        CapacityInterpolation;
        %Interpolation of the adsorption efficiency based on the current
        %fill percentage of the adsorber bed
        AdsorbInterpolant;
        
        %Effective Area for the heat transfer between zeolite and gas
        fEffectiveZeoliteArea;
        
        %Time this filter remains in either desorb or adsorb mode (assumes
        %that both take the exact same amount of time)
        fCycleTime;
        %Time that is used for air safe mode at the beginning of desorption
        fAirSafeTime = 0;
        %Total amount of mass that has to be desorbed during the desorption
        %phase. Used to calculate the flow rate
        fDesorbMass = 0;
        %Last time this proc was executed.
        fLastExec = 0;
        
    end
    
    methods
        function this = Filter(oStore, sName, sPhaseIn, sPhaseOut, sType, fCycleTime, fAirSafeTime)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.sType = sType;
            this.fCycleTime = fCycleTime;
            if nargin == 8
                this.fAirSafeTime = fAirSafeTime;
            end
            
            if strcmp(this.sType, 'Filter5A')
                %Filter 5A absorbs CO2 so the value for CO2 is set to one
                this.arExtractPartials = zeros(1, this.oMT.iSubstances);
                this.arExtractPartials(this.oMT.tiN2I.CO2) = 1;
                this.sSpecies = 'CO2';
                
                %the values are given in g CO2 per 100g Zeolith.
                %The g value has no effect since the ratio remains
                %the same for kg
                this.mfZeolithCapacity = load(strrep('lib\+components\CDRA\components\ZeolithCapacity.mat', '\', filesep));
                this.CapacityInterpolation = griddedInterpolant((this.mfZeolithCapacity.T)', (this.mfZeolithCapacity.P)', (this.mfZeolithCapacity.C)');
                
                %TO DO: Check this?
                fDensityZeolith = 114.7151779 * 1.22; %i didn't check this so far, it is the value used by the previous works

                %At ICES 2015 it was mentioned during one session that the mean
                %diameter of the zeolite 5A pellets is 2.1 mm which is
                %concurrent with alibaba producer information that the size is
                %between 1.6mm and 5mm. By using the volume for one sphere the
                %mass of each sphere can be calculated which can then be used
                %to calculate the number of spheres in the filter
                fMassPerSphere = fDensityZeolith*(4/3)*pi*((0.0021/2)^3);
                fNZeoliteSpheres = this.oOut.oPhase.afMass(this.oMT.tiN2I.Zeolite5A)/fMassPerSphere;

                %and with that the area is:
                this.fEffectiveZeoliteArea = fNZeoliteSpheres*4*pi*0.0025^2;
                %Of course this is only an estimate and the zeolite will
                %generally be packed more closely but at the same time the spheres
                %will be touching each other which reduces the area for the
                %heat transfer to the gas again. So this can be seen as a good
                %estimate for the effective area in the heat transfer.
                
                %% Curve Fitting for Adsorption Efficiency of Zeolite 5A
                % WARNING: REQUIRES CURVE FITTING TOOLBOX!

                %Test Data from Figure 30 of  "Full System Modeling and Validation of the
                %Carbon Dioxide Removal Assembly" Robert Coker, James Knox, Hernando Gauto, Carlos Gomez 
                %ICES-2014-168 was used to generate this time over efficiency
                %profile for zeolite 5A:
                %The reason why figure 30 was chosen is because it shows
                %Zeolite 5A 38K which according to "Development of Carbon Dioxide Removal Systems 
                %for Advanced Exploration Systems 2013-2014" James C. Knox 1 , Hernando Gauto 2 , Rudy Gostowski 3 , David Watson 4 
                %ICES-2014-160 page 3 is the current zeolite 5A that is
                %used in the station CDRA
                
                %The data was only available as figure so this
                %interpolation tries to replicate it as close as possible.
                mTime1 = 0:1:20;
                mAbsorbEfficiency1 = 100:-0.1:98;
                mTime2 = 80:1:100;
                mAbsorbEfficiency2 = 3:-0.1:1;
                mTime              =     [             mTime1, 50,              mTime2].*60;
                mAbsorbEfficiency  =     [ mAbsorbEfficiency1, 50,  mAbsorbEfficiency2].*0.01;

                mTime = mTime';
                mAbsorbEfficiency = mAbsorbEfficiency';

                %curve fitting toolbox command to fit a curve through the
                %efficiency over time data:
                TimeEfficiencyInterpolant = fit(mTime, mAbsorbEfficiency, 'cubicinterp');

                %now by assuming that simply 1kg of mass flow goes into the CO2
                %the absorbed CO2 can be calculated by integrating the
                %efficiency interpolant over time (note the mass flow is
                %unrealistic but does not actually matter since it is just 
                %used to get a value for the efficiency over the current 
                %percent fill status of the bed which makes it independent 
                %from the mass flow value used at this point)
                mAbsorbedCO2 = zeros(100,1);
                mPercentFilled = zeros(100,1);
                for k = 1:100
                    mAbsorbedCO2(k) = integrate(TimeEfficiencyInterpolant,k*60,0);
                end
                %now the mass of absorbed CO2 calculated from this integration
                %can be used to get values for the efficiency over a percent
                %filled graph (basically efficiency over the percentage of how
                %near the maximum capacity the bed is)
                for k = 1:100
                    mPercentFilled(k) = mAbsorbedCO2(k)/max(mAbsorbedCO2);
                    mAbsorbEfficiency(k) = TimeEfficiencyInterpolant(k*60);
                end
                %these values are then used to generate the actual
                %interpolation used later on
                this.AdsorbInterpolant = fit(mPercentFilled, mAbsorbEfficiency, 'smoothingspline');
                % This way the interpolation is independant from both time
                % and actual mass and therefore easily adaptable to very
                % different sized filters (of course it is not possible to
                % guarantee that the test data matches all filter sizes but
                % it is definitly more accurate than other blind
                % assumptions with no supporting data at all)
                
                %if you want to view the resulting curve simply use this
                %command: plot(this.AdsorbInterpolant)
                %plot(TimeEfficiencyInterpolant)
                
            elseif strcmp(this.sType, 'Filter_13x')
                %Filter 13x absorbs water
                this.arExtractPartials = zeros(1, this.oMT.iSubstances);
                this.arExtractPartials(this.oMT.tiN2I.H2O) = 1;
                this.sSpecies = 'H2O';
                
                % For zeolite 13x ~ 180 g of water can be absorbed into 1kg
                % of zeolite 
                % TO DO: make better interpolation
                this.CapacityInterpolation = 0.18;
                %% Curve Fitting for Adsorption Efficiency of Zeolite 13x
                % WARNING: REQUIRES CURVE FITTING TOOLBOX!

                %Test Data from Figure 14 of  "Full System Modeling and Validation of the
                %Carbon Dioxide Removal Assembly" Robert Coker, James Knox, Hernando Gauto, Carlos Gomez 
                %ICES-2014-168 was used to generate this time over efficiency
                %profile for zeolite 13x:
                %The inlet vapor pressure is mentioned on page 21 in the
                %paper for this test to be 1.2 kPa and this was used to
                %estimate the adsorption efficiency
                mTime              =     [   0,    25,    50, 100, 150, 200, 225, 250, 275, 300, 325].*60;
                mAbsorbEfficiency  =     [ 100,  99.9, 99.95,  99,  90,  66,  33,  16,   8,   4,   1].*0.01;

                mTime = mTime';
                mAbsorbEfficiency = mAbsorbEfficiency';

                %curve fitting toolbox command to fit a curve through the
                %efficiency over time data:
                TimeEfficiencyInterpolant = fit(mTime, mAbsorbEfficiency, 'smoothingspline');

                %now by assuming that simply 1kg of mass flow goes into the
                %filter the absorbed mass can be calculated by integrating the
                %efficiency interpolant over time (note the mass flow is
                %unrealistic but does not actually matter since it is just 
                %used to get a value for the efficiency over the current 
                %percent fill status of the bed which makes it independent 
                %from the mass flow value used at this point)
                mAbsorbedCO2 = zeros(325,1);
                mPercentFilled = zeros(325,1);
                for k = 1:325
                    mAbsorbedCO2(k) = integrate(TimeEfficiencyInterpolant,k*60,0);
                end
                %now the adsorbed mass calculated from this integration
                %can be used to get values for the efficiency over a percent
                %filled graph (basically efficiency over the percentage of how
                %near the maximum capacity the bed is)
                for k = 1:325
                    mPercentFilled(k) = mAbsorbedCO2(k)/max(mAbsorbedCO2);
                    mAbsorbEfficiency(k) = TimeEfficiencyInterpolant(k*60);
                end
                %these values are then used to generate the actual
                %interpolation used later on
                this.AdsorbInterpolant = fit(mPercentFilled, mAbsorbEfficiency, 'smoothingspline');
                % This way the interpolation is independant from both time
                % and actual mass and therefore easily adaptable to very
                % different sized filters (of course it is not possible to
                % guarantee that the test data matches all filter sizes but
                % it is definitly more accurate than other blind
                % assumptions with no supporting data at all)
                
                %if you want to view the resulting curve simply use this
                %command: plot(this.AdsorbInterpolant)
                %plot(TimeEfficiencyInterpolant)
            else
                error('No data available for the specified filter type and therefore the calculation of it is not possible. You can however add the required data and add the filter type to the possible inputs to enable calculations');
            end
        end
        
        function update(this)
            
            %Gets the index in the matter table for the substance this
            %filter is adsorbing
            iSpecies = this.oMT.tiN2I.(this.sSpecies);
            
            %calculates the current time step
            fTimeStep = this.oStore.oTimer.fTime - this.fLastExec;
            
            if fTimeStep <= 0.1
                return
            end
            
            if this.oStore.oContainer.fFlowrateMain == 0
                this.fFlowRateFilter = 0;
                this.arExtractPartials = zeros(1,this.oMT.iSubstances);
                this.setMatterProperties(this.fFlowRateFilter, this.arExtractPartials);
                return
            end
            
            % gets the current inlet flowrates and their partial mass
            % ratios
            [ afFlowRate, mrPartials ] = this.getInFlows();
            if isempty(afFlowRate)
                fFlowRateSpecies = 0;
            else
                %Calculates the total ingoing flowrate for the substance
                %that is beeing adsorbed by this filter
                afFlowRateSpecies = afFlowRate .* mrPartials(:, iSpecies);
                fFlowRateSpecies = sum(afFlowRateSpecies);
            end
            
            switch this.sFilterMode
                case 'absorb'

                    if strcmp(this.sType, 'Filter5A')
                        fPPCO2 = this.oIn.oPhase.afPP(this.oMT.tiN2I.CO2);

                        % Capacity calculation
                        if this.oOut.oPhase.fTemperature > 273.15
                            fTempFilter = this.oOut.oPhase.fTemperature;
                        else
                            fTempFilter = 273.15;
                        end

                        %Note the interpolation is divided with 100 because
                        %the values are given in g CO2 per 100g Zeolith.
                        %The g value has no effect since the ratio remains
                        %the same for kg
                        this.fCapacity = this.oOut.oPhase.afMass(this.oMT.tiN2I.Zeolite5A) * (this.CapacityInterpolation(abs(fTempFilter), abs(fPPCO2)) / 100);
                        if isnan(this.fCapacity) || this.fCapacity < 0
                            this.fCapacity = 0;
                        end
                    else
                        this.fCapacity = this.oOut.oPhase.afMass(this.oMT.tiN2I.Zeolite5A) * this.CapacityInterpolation;
                    end
                    
                    %Now the current fill status of the bed is calculated
                    %in percent:
                    fPercentFilled = this.oOut.oPhase.afMass(iSpecies)/this.fCapacity;
                    if fPercentFilled > 1
                        % if the filter adsorbed more mass than it has
                        % capacity (which can happen if the CO2 or
                        % temperature levels change) the filter desorbs the
                        % the excess amount of mass. (negative flow rate
                        % means that mass from the filter is moved to the
                        % air stream)
                        fMassToDesorb = (this.fCapacity-this.oOut.oPhase.afMass(iSpecies)); 
                        % Assumes that 1% of the exceed mass is desorbed
                        % per second
                        fBaseDesorbFlow = fMassToDesorb/100;
                        % the higher the capacity is exceeded the larger
                        % the desorption flow rate will be
                        this.fFlowRateFilter = (abs(fMassToDesorb)/this.fCapacity)*fBaseDesorbFlow;
                        % if the desorption flow is to large it is limited
                        if this.fFlowRateFilter < -1e-2
                            this.fFlowRateFilter = -1e-2;
                        end
                    elseif fPercentFilled < 0.99
                        %to prevent oscillations it only adsorbs more if it
                        %is below 99% of its maximum capacity
                        fEfficiency = this.AdsorbInterpolant(fPercentFilled);
                        if fEfficiency > 1
                            %because of the smoothing interpolations used
                            %the efficiency sometimes is slightly larger
                            %than 1, this effect is removed here by
                            %setting larger values to 1
                            fEfficiency = 1;
                        end
                        %The adsorbed mass flow is the adsorption
                        %efficiency time the current flow rate for the
                        %substance
                        this.fFlowRateFilter = fEfficiency*fFlowRateSpecies;
                    else
                        this.fFlowRateFilter = 0;
                    end
                    
                    %Sets the desorption mass to zero so that it can be
                    %initialized at the next desorption phase
                    this.fDesorbMass = 0;

                case 'desorb'

                    %If the mass currently in the filter is higher than the
                    %current value for the mass that should be desorbed the
                    %value is overwritten (note that fDesobMass is set to 0
                    %in the adsorption phase)
                    if this.oOut.oPhase.afMass(iSpecies) > this.fDesorbMass
                        this.fDesorbMass = this.oOut.oPhase.afMass(iSpecies);
                    end
                    
                    %Note that for desorption no test data was available!
                    
                    %Basically the way it works is the same as for the
                    %adsorption case. If the filter is full the desorb
                    %flowrate is high if it is nearly empty the flowrate is
                    %lower. Therefore this was changed to work the same way
                    %the new adsorption flowrate now works. However it
                    %should be ensured that the filter is able to empty
                    %completly during its cycle time. Therefore the average
                    %value of the effciency factor over the cycle time has
                    %to be 1 so that the full mass is desorbed during one
                    %cylce. 
                    %Now assuming that the desorption flowrate follows a
                    %root profile that has to desorb the whole mass
                    %that was adsorbed this equation can be found:
                    % 3*(1-(t^0.5/T^0.5)
                    % with t being the current time in this cycle and T 
                    % being the cyle time
                    
                    %To prove that this desorbs the full mass of the filter
                    %over one cycle time the average factor over the cycle 
                    %can be calculated by integrating this function over the
                    %time and dividing it with the cycle time: 
                    %(3)*1/T*[t-(2/3)*t^(3/2)*(1/T^(1/2))] from 0 to T
                    %Which leads to a factor of 1 as average and thus
                    %ensures that the full adsorbed mass is desorbed within
                    %the cycle time! (yes the function was chosen to reach
                    %1 as average ;)
                    
                    fCurrentCycleTime = mod(this.oStore.oTimer.fTime, this.fCycleTime);
                    %This factor basically decide at which point during the
                    %air safe mode the filter starts desorbing CO2. That
                    %the CDRA filter does desorb CO2 during its airsafe
                    %mode can be seen in the test data for CDRA in
                    %00ICES-234: "International Space Station Carbon Dioxide
                    %Removal Assembly Testing" James C. Knox
                    %And this specific value was chosen through try and
                    %error to match the CO2 spike the CDRA shows in this test.
                    fDesorbStartFactor = 0.65;
                    if (fCurrentCycleTime/this.fAirSafeTime) <= fDesorbStartFactor
                        %While the pressure is still high (in air safe
                        %mode) the filter should not desorb
                        this.fFlowRateFilter = 0;
                    else
                        %In order to account for numerical issues sometimes
                        %cutting the desorption time alittle bit short the
                        %factor is 3.01 instead of 3.
                        fEfficiencyFactor = (3.01*(1-(sqrt(fCurrentCycleTime-(fDesorbStartFactor*this.fAirSafeTime))/sqrt(this.fCycleTime-(fDesorbStartFactor*this.fAirSafeTime)))));

                        this.fFlowRateFilter = -(this.fDesorbMass / (this.fCycleTime-(fDesorbStartFactor*this.fAirSafeTime)))*fEfficiencyFactor;

                        %if everything has been desorbed set flowrate to 0
                        %to prevent V-HAB from generating/deleting mass
                        if this.oOut.oPhase.afMass(iSpecies) < 1e-6
                            this.fFlowRateFilter = 0;
                        end
                    end
                    
                    %during desorption the capacity is set to 0
                    this.fCapacity = 0;
                      
                    fAvailableMassFlow = this.oOut.oPhase.afMass(this.arExtractPartials ~= 0) / fTimeStep;

                    if this.fFlowRateFilter > fAvailableMassFlow
                        this.fFlowRateFilter = fAvailableMassFlow;
                    end
            end
            
            [ afInFlowrates, mrInPartials ] = this.getInFlows();
            afInFlows = sum(afInFlowrates .* mrInPartials,1);
            
            if afInFlows(this.oMT.tiN2I.CO2) < (this.fFlowRateFilter * this.arExtractPartials(this.oMT.tiN2I.CO2))
                this.fFlowRateFilter = afInFlows(this.oMT.tiN2I.CO2);
            end
            
            %this sets the actual filter flow rate for the p2p processor
            this.setMatterProperties(this.fFlowRateFilter, this.arExtractPartials);
            
            %% Thermal Calculation for the filter
            % CDRA uses heaters to increase the zeolite temperature of the
            % filter but this effect is countered to some degree by the
            % cooling of the mass flowing through the filter. This
            % calculation derives the overall heat flow for this case and
            % sets the energy change to the phase
            if strcmp(this.sType, 'Filter5A')
                %The heat flow from the heaters is saved as property to
                %this proc while the heat flow between the zeolite and the 
                %flow is saved in the filter f2f proc. For the temperature
                %change of the zeolite the overall heat flow can be
                %calculated by subtracting the heatflow going into the flow
                %from the heat heat flow:
                
                fOverallHeatFlow = this.fHeatFlow - this.oF2F.fHeatFlow;
                
                this.oOut.oPhase.oCapacity.toHeatSources.AbsorberHeatSource.setHeatFlow(fOverallHeatFlow);
                
            end
            
            
            %saves the last time this processor was executed
            this.fLastExec = this.oStore.oTimer.fTime;
        end
        
        %Function to change the filter mode between adsorption and
        %desorption. Allowed inputs are: 'desorb' or 'absorb'
        function setFilterMode(this, FilterMode)
            this.sFilterMode = FilterMode;
        end
        
        %Function to set the zeolite heater power that is used during
        %desorption to increase the zeolite temperature
        function setHeaterPower(this, HeaterPower)
            this.fHeatFlow = HeaterPower;
        end
        
        %Function to set the f2f proc asscociated with this filter
        function setF2F(this, oF2F)
            this.oF2F = oF2F;
        end
    end
end