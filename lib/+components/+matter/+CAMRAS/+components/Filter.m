classdef Filter < matter.procs.p2ps.stationary
    
    % Filter for the CAMRAS CO2 absorbtion Subsystem
    
    properties (SetAccess = protected, GetAccess = public)
        sSpecies;                       % Species to absorb
        fCapacity;                      % Max absorb capacity in kg
        arExtractPartials;              % Defines which species are extracted
        sFilterMode;                    % Defines wheter the filter absorbs oder desorbs
        fFlowRateFilter = 0;            % Flow rate of the matter, which gets filtered
        sType;
        
        %Time this filter remains in either desorb or adsorb mode (assumes
        %that both take the exact same amount of time)
        fCycleTime;
        
        % Time to create vacuum --> no desorbing during this time
        fVacuumTime;
        
        % Time to equalize pressure --> no desorbing during this time
        fPressureCompensationTime
        
        %Total amount of mass that has to be desorbed during the desorption
        %phase. Used to calculate the flow rate
        fDesorbMass = 0;
        
        %Last time this proc was executed.
        fLastExec = 0;
        
        %Actual Efficiency considering degregation over cycle time
        fEfficiency = 0;
        
        % Averaged Efficiency
        fEfficiencyAveraged = 0;
        
        % Ratio of Species Inlet Flow to total Inlet Flow
        fMassRatioSpecies;
        
        % Case is oriented on crew member case and can be nominal, exercise or sleep
        sCase;
        
        % internal CAMRAS time
        fInternalTime = 0;
        
        
        % Variables that are needed for on/off process
        iOn = 0;
        
        iOff = 0;
        
    end
    
    methods
        function this = Filter(oStore, sName, sPhaseIn, sPhaseOut, sType, fCycleTime, fVacuumTime,fPressureCompensationTime, sCase)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            this.sType = sType;
            this.fCycleTime = fCycleTime;
            this.fVacuumTime = fVacuumTime;
            this.sCase = sCase;
            this.fPressureCompensationTime = fPressureCompensationTime;
            
            
            if strcmp(this.sType, 'CO2')
                
                this.arExtractPartials = zeros(1, this.oMT.iSubstances);
                this.arExtractPartials(this.oMT.tiN2I.CO2) = 1;
                this.sSpecies = 'CO2';
                
                
            elseif strcmp(this.sType, 'H2O')
                
                this.arExtractPartials = zeros(1, this.oMT.iSubstances);
                this.arExtractPartials(this.oMT.tiN2I.H2O) = 1;
                this.sSpecies = 'H2O';
                
                
            else
                error('No data available for the specified filter type and therefore the calculation of it is not possible. You can however add the required data and add the filter type to the possible inputs to enable calculations');
            end
        end
        
        function setCycleTime(this, fCycleTime)
            this.fCycleTime = fCycleTime;
        end
        
        function setCase(this, sCase)
            this.sCase = sCase;
        end
        
        function setOn(this)
            this.iOff = 0;
        end
        
        function setOff(this)
            this.iOff = 1;
        end
        
        %Function to change the filter mode between adsorption and
        %desorption. Allowed inputs are: 'desorb' or 'absorb'
        function setFilterMode(this, FilterMode)
            this.sFilterMode = FilterMode;
        end
    end
    methods (Access = protected)
        function update(this)
            % Internal time relative time for full cycle
            this.fInternalTime = this.oStore.oContainer.fInternalTime;
            
            % Internal time relative time for half cycle
            fCurrentCycleTime = mod(this.fInternalTime, this.fCycleTime);
            
            %Gets the index in the matter table for the substance this
            %filter is adsorbing
            iSpecies = this.oMT.tiN2I.(this.sSpecies);
            
            %calculates the current time step
            fTimeStep = this.oStore.oTimer.fTime - this.fLastExec;
            
            if fTimeStep <= 0
                return
            end
            
            
            % If the System is off the flow rate is set to zero and no
            % absorbing / desorbing process takes place
            if this.oStore.oContainer.fFlowrateMain == 0
                this.fFlowRateFilter = 0;
                this.setMatterProperties(this.fFlowRateFilter, this.arExtractPartials);
                return
            end
            
            % While pressure equalization takes place no
            % avsorbtion/desorbtion takes place. Since the plots of the
            % efficiency courves look weird otherweise during this time
            % both are set to nan
            if mod(fCurrentCycleTime,this.fCycleTime)  < (this.fPressureCompensationTime)
                this.fEfficiencyAveraged = nan;
                this.fEfficiency = nan;
                this.fFlowRateFilter = 0;
                this.setMatterProperties(this.fFlowRateFilter, this.arExtractPartials);
                return
            end
            
            
            %%%%%%%%%%%%%%%%% Now the real absorbtion / desorbtion process starts:
            
            
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
                fFlowRateTotal = sum(afFlowRate);
                
                this.fMassRatioSpecies = fFlowRateSpecies/fFlowRateTotal;
                
            end
            
            switch this.sFilterMode
                case 'absorb'
                    
                    % Efficiency curves as a function of the mass ratio of the respective substance
                    % are available for CO2 and H2O as well as for the three differen cases
                    
                    
                    if strcmp(this.sType, 'CO2')
                        
                        if strcmp(this.sCase, 'nominal')
                            this.fEfficiencyAveraged = (-105.26 *  this.fMassRatioSpecies + 86.121)/100;
                            
                        elseif strcmp(this.sCase, 'exercise')
                            this.fEfficiencyAveraged = (-5690.5 *  this.fMassRatioSpecies + 90.067)/100;
                            
                            
                        elseif strcmp(this.sCase, 'sleep')
                            this.fEfficiencyAveraged = (284.45 *  this.fMassRatioSpecies + 88.173)/100;
                            
                        elseif strcmp(this.sCase, 'off')
                            this.fEfficiencyAveraged = 0;
                        else
                            keyboard();
                        end
                        
                    elseif strcmp(this.sType, 'H2O')
                        
                        if strcmp(this.sCase, 'nominal')
                            this.fEfficiencyAveraged = (1000 *  this.fMassRatioSpecies + 87.2)/100;
                            
                        elseif strcmp(this.sCase, 'exercise')
                            this.fEfficiencyAveraged = (490.12 *  this.fMassRatioSpecies + 83.895)/100;
                            
                        elseif strcmp(this.sCase, 'sleep')
                            this.fEfficiencyAveraged = (1049.5 *  this.fMassRatioSpecies + 88.936)/100;
                            
                        elseif strcmp(this.sCase, 'off')
                            this.fEfficiencyAveraged = 0;
                        else
                            keyboard();
                        end
                        
                    end
                    
                    if this.iOff ==1
                        this.fEfficiencyAveraged = 0;
                    end
                    
                    
                    % Consider Degregation over Cycle time by overlying
                    % efficiency with a linear function starting at 130%
                    %  and ending at 70% less of averaged efficiency
                    fCurrentCycleTime = mod(this.fInternalTime, this.fCycleTime) ;
                    
                    if strcmp(this.sType, 'CO2')
                        fDegrad = -0.6/((this.fCycleTime)-(this.fPressureCompensationTime)) * (fCurrentCycleTime - this.fPressureCompensationTime) + 1.3; % Lineare Funktion mit Startwert 1.2 (+ 20%)  und Endwert 0.8 (- 20%) nach Cycle Time
                    elseif strcmp(this.sType, 'H2O')
                        fDegrad = -0.3/((this.fCycleTime)-(this.fPressureCompensationTime)) * (fCurrentCycleTime - this.fPressureCompensationTime) + 1.15;
                    end
                    this.fEfficiency = fDegrad * this.fEfficiencyAveraged;
                    
                    % Takes care that the efficiencies are whithin
                    % physically locical limits
                    
                    if this.fEfficiency > 1
                        this.fEfficiency = 1;
                    elseif this.fEfficiency < 0
                        this.fEfficiency = 0;
                    end
                    
                    
                    % Now the flow rate of scrubbed material into the
                    % filter is calculated. It is set later in the script
                    % using the set.MatterPropertiy function
                    this.fFlowRateFilter = this.fEfficiency * fFlowRateSpecies;
                    
                    % Desorb Mass needs to be set to zero during absorbing
                    % phase
                    this.fDesorbMass = 0;
                    
                    
                case 'desorb'
                    
                    this.fEfficiency = 0;
                    this.fEfficiencyAveraged = 0;
                    
                    %If the mass currently in the filter is higher than the
                    %current value for the mass that should be desorbed the
                    %value is overwritten (note that fDesobMass is set to 0
                    %in the adsorption phase)
                    if this.oOut.oPhase.afMass(iSpecies) > this.fDesorbMass
                        this.fDesorbMass = this.oOut.oPhase.afMass(iSpecies);
                    end
                    
                    
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
                    
                    % Since sometimes the desorbtion ended too early the
                    % prefactor of 3 was changed to 2.985
                    
                    
                    fCurrentCycleTime = mod(this.fInternalTime, this.fCycleTime);
                    
                    % Desorbtion only takes place after the pressure swing
                    % was performed as well as the vacuum created
                    if mod(fCurrentCycleTime,this.fCycleTime)  > (this.fVacuumTime + this.fPressureCompensationTime)
                        
                        
                        fEfficiencyFactor = (2.985 *(1-(sqrt(fCurrentCycleTime-(this.fVacuumTime + this.fPressureCompensationTime))/sqrt(this.fCycleTime-(this.fVacuumTime + this.fPressureCompensationTime)))));
                        
                        this.fFlowRateFilter = - 1 * ((this.fDesorbMass - 0.002) / (this.fCycleTime-(this.fVacuumTime + this.fPressureCompensationTime)))*fEfficiencyFactor;
                        
                        
                        %if everything has been desorbed set flowrate to 0
                        %to prevent V-HAB from generating/deleting mass
                        if this.oOut.oPhase.afMass(iSpecies) < 0.002
                            this.fFlowRateFilter = 0;
                        end
                        
                    else
                        this.fFlowRateFilter = 0;
                    end
                    
                    %during desorption the capacity is set to 0
                    this.fCapacity = 0;
                    
                    fAvailableMassFlow = this.oOut.oPhase.afMass(this.arExtractPartials ~= 0) / fTimeStep;
                    
                    if this.fFlowRateFilter > fAvailableMassFlow
                        this.fFlowRateFilter = fAvailableMassFlow;
                    end
            end
            
            %this sets the actual filter flow rate for the p2p processor
            this.setMatterProperties(this.fFlowRateFilter, this.arExtractPartials);
            
            
            %saves the last time this processor was executed
            this.fLastExec = this.oStore.oTimer.fTime;
        end
    end
end