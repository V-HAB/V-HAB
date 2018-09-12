function update(this, ~)
%UPDATE Updates the phases inside this store
% Update phases, then recalculate internal values as volume
% available for phases.

this.fTimeStep   = this.fDefaultTimeStep;

% Set the default time step - can be overwritten by phases
this.setTimeStep(this.fTimeStep);

%%
%calculates the volume of liquid and gas phase if both phases are present
%in one store

%getting the values for gas and liquid phases in the tank

iGasPhaseExists = 0;
for k = 1:length(this.aoPhases)
    if strcmp(this.aoPhases(k).sType, 'gas')
        iGasPhaseExists = 1;
    end
end

if this.bIsIncompressible == 0 && iGasPhaseExists == 1 && (this.oTimer.fTime-this.fLastUpdate) > 0
    %TODO: clean this up and make it more accessible, also
    %      check for molar mass compatibility (g/mol vs kg/mol)
    
    %ideal gas constant
    fR = this.oMT.Const.fUniversalGas;
    
    for k = 1:length(this.aoPhases)
        if strcmp(this.aoPhases(k).sType, 'gas')
            fVolumeGasOld = this.aoPhases(k).fVolume;
            fMolarMassGas = this.aoPhases(k).fMolarMass;
            fMassGasOld = this.aoPhases(k).fMass;
            fMassGasTimeStep = this.oTimer.fTime-this.aoPhases(k).fLastMassUpdate;
            fTemperatureGasOld = this.aoPhases(k).fTemperature;
            if ~isempty(this.aoPhases(k).coProcsEXME)
                mFlowRateGas = zeros(length(this.aoPhases(k).coProcsEXME),1);
                mPressureGasFlow = zeros(length(this.aoPhases(k).coProcsEXME),1);
                mTemperatureGasFlow = zeros(length(this.aoPhases(k).coProcsEXME),1);
                mMolMassGasFlow = zeros(length(this.aoPhases(k).coProcsEXME),1);
                mDensityGasFlow = zeros(length(this.aoPhases(k).coProcsEXME),1);
                for n = 1:length(this.aoPhases(k).coProcsEXME)
                    mFlowRateGas(n) = this.aoPhases(k).coProcsEXME{n}.aiSign*this.aoPhases(k).coProcsEXME{n}.aoFlows.fFlowRate;
                    mPressureGasFlow(n) = this.aoPhases(k).coProcsEXME{n}.aoFlows.fPressure;
                    mTemperatureGasFlow(n) = this.aoPhases(k).coProcsEXME{n}.aoFlows.fTemperature;
                    mMolMassGasFlow(n) = this.aoPhases(k).coProcsEXME{n}.aoFlows.fMolarMass;
                    mDensityGasFlow(n) = (fR*mTemperatureGasFlow(n))/(mMolMassGasFlow(n)*mPressureGasFlow(n));
                end
            else
                mFlowRateGas = 0;
            end
        end
        
        if strcmp(this.aoPhases(k).sType, 'liquid')
            fMassLiquidOld = this.aoPhases(k).fMass;
            fMassLiquidTimeStep = this.oTimer.fTime-this.aoPhases(k).fLastMassUpdate;
            fTemperatureLiquidOld = this.aoPhases(k).fTemperature;
            if ~isempty(this.aoPhases(k).coProcsEXME)
                mFlowRateLiquid = zeros(length(this.aoPhases(k).coProcsEXME),1);
                mPressureLiquidFlow = zeros(length(this.aoPhases(k).coProcsEXME),1);
                mTemperatureLiquidFlow = zeros(length(this.aoPhases(k).coProcsEXME),1);
                mDensityLiquidFlow = zeros(length(this.aoPhases(k).coProcsEXME),1);
                for n = 1:length(this.aoPhases(k).coProcsEXME)
                    mFlowRateLiquid(n) =  this.aoPhases(k).coProcsEXME{n}.iSign*this.aoPhases(k).coProcsEXME{n}.oFlow.fFlowRate;
                    mPressureLiquidFlow(n) = this.aoPhases(k).coProcsEXME{n}.oFlow.fPressure;
                    mTemperatureLiquidFlow(n) = this.aoPhases(k).coProcsEXME{n}.oFlow.fTemperature;
                    mDensityLiquidFlow(n) = this.oMT.calculateDensity(this.aoPhases(k).coProcsEXME{n}.oFlow);
                end
            else
                mFlowRateLiquid = 0;
            end
        end
    end
    
    if max(abs(mFlowRateLiquid)) ~= 0 || max(abs(mFlowRateGas)) ~= 0
        fTimeStepVolume = min(fMassGasTimeStep, fMassLiquidTimeStep);
        fMassGas = fMassGasOld + fTimeStepVolume*sum(mFlowRateGas);
        fMassLiquid = fMassLiquidOld + fTimeStepVolume*sum(mFlowRateLiquid);
        
        % The left and right border for the search intervall are calculated
        % (The if query has to be so long and calculate with abs() because
        % the place where the values are added/subtracted changes depending
        % on their direction)
        if sum(mFlowRateLiquid) > 0 && sum(mFlowRateGas) == 0
            % For no gas flows and a positiv liquid flow the lower volume
            % boundary can be defined by subtracting the volume of water
            % that flowed into the store from the old gas volume while
            % assuming the liquid to be incompressible
            fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
            % The higher volume boundary is simply the old gas volume
            fVolumeGas_Y = fVolumeGasOld;
            
        elseif sum(mFlowRateLiquid) < 0 && sum(mFlowRateGas) == 0
            % For no gas flows and a negativ liquid flow the lower volume
            % boundary is simply the old gas volume
            fVolumeGas_X = fVolumeGasOld;
            % The higher volume boundary can be defined by adding the
            % volume of water that flowed out of the store to the old gas
            % volume while assuming the liquid to be incompressible
            fVolumeGas_Y = fVolumeGasOld  + abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
            
        elseif sum(mFlowRateGas) > 0 && sum(mFlowRateLiquid) == 0
            % For no liquid flow and a positiv gas flow the lower volume
            % boundary is simply the old gas volume
            fVolumeGas_X = fVolumeGasOld;
            % The higher volume boundary can be defined by adding the
            % volume of gas that flowed into the store to the old gas
            % volume assuming the volume flow to be incompressible
            fVolumeGas_Y = fVolumeGasOld  + abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow));
            
        elseif sum(mFlowRateGas) < 0 && sum(mFlowRateLiquid) == 0
            mDensityGasFlow = (fR*mTemperatureGasFlow)/(fMolarMassGas*mPressureGasFlow);
            % For no liquid flow and a negativ gas flow the lower volume
            % boundary can be defined by subtracting the volume of gas that
            % flowed into the store to the old gas volume assuming the
            % volume flow to be incompressible
            fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow));
            % The higher volume boundary is simply the old gas volume
            fVolumeGas_Y = fVolumeGasOld;
            
        elseif sum(mFlowRateLiquid) >= 0 && sum(mFlowRateGas) >= 0
            % In the case that both flow are positive the lower volume
            % boundary can be defined by subtracting the incompressible
            % volumeflow of water from the old gas volume
            fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
            % The higher volume boundary can be defined by adding the
            % incompressible volumeflow of gas into the tank to the old gas
            % volume
            fVolumeGas_Y = fVolumeGasOld + abs((fTimeStepVolume*mFlowRateGas)/mDensityGasFlow);
            
        elseif sum(mFlowRateLiquid) < 0 && sum(mFlowRateGas) >= 0
            % In the case that the liquid flow is negative and the gas flow
            % positive the lower volume boundary is simply the old gas
            % volume
            fVolumeGas_X = fVolumeGasOld;
            % The higher volume boundary can be defined by adding the
            % incompressible volumeflow of gas into the tank to the old gas
            % volume and subtracting the incompressible water flow from the
            % tank as well
            fVolumeGas_Y = fVolumeGasOld + abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow))  - abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
            
        elseif sum(mFlowRateLiquid) >= 0 && sum(mFlowRateGas) < 0
            % In the case that the liquid flow is positive and the gas flow
            % negative the lower volume boundary can be defined by
            % subtracting the incompressible volumeflow of gas into the
            % tank from the old gas volume and subtracting the
            % incompressible water flow from the tank as well
            fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow))  - abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
            % The higher volume boundary is simply the old gas volume
            fVolumeGas_Y = fVolumeGasOld;
            
        elseif sum(mFlowRateLiquid) < 0 && sum(mFlowRateGas) < 0
            % In the case that both flow are negative the lower volume
            % boundary can be defined by subtracting the incompressible
            % volumeflow of gas from the old gas volume
            fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow));
            % The higher volume boundary can be defined by adding the
            % incompressible volumeflow of water into the tank to the old
            % gas volume
            fVolumeGas_Y = fVolumeGasOld + abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
        end
        for k = 1:length(mFlowRateGas)
            if mFlowRateGas(k) == 0
                mDensityGasFlow(k) = 1;
            end
        end
        for k = 1:length(mFlowRateLiquid)
            if mFlowRateLiquid(k) == 0
                mDensityLiquidFlow(k) = 1;
            end
        end
        
        fErrorStore_X = 1;
        fErrorStore_Y = 1;
        counter1 = 1;
        % If the two borders do not contain the zepoint it is necessary to
        % shift the borders until they contain it
        while sign(fErrorStore_X) == sign(fErrorStore_Y) && counter1 <= 500
            fDensityLiquid_X = fMassLiquid/(this.fVolume-fVolumeGas_X);
            fPressureGas_X = (fMassGas*fR*fTemperatureGasOld)/(fMolarMassGas*fVolumeGas_X);
            
            %TODO Replace this with a calculatePressure() method in the
            %     matter table that takes all contained substances into 
            %     account, not just water.
            tParameters = struct();
            tParameters.sSubstance = 'H2O';
            tParameters.sProperty = 'Pressure';
            tParameters.sFirstDepName = 'Density';
            tParameters.fFirstDepValue = fDensityLiquid_X;
            tParameters.sPhaseType = 'liquid';
            tParameters.sSecondDepName = 'Temperature';
            tParameters.fSecondDepValue = fTemperatureLiquidOld;
            tParameters.bUseIsobaricData = false;
            
            fPressureLiquid_X = this.oMT.findProperty(tParameters);
            fErrorStore_X = fPressureGas_X-fPressureLiquid_X;
            
            fDensityLiquid_Y = fMassLiquid/(this.fVolume-fVolumeGas_Y);
            fPressureGas_Y = (fMassGas*fR*fTemperatureGasOld)/(fMolarMassGas*fVolumeGas_Y);
            
            %TODO Replace this with a calculatePressure() method in the
            %matter table that takes all contained substances into account,
            %not just water.
            tParameters = struct();
            tParameters.sSubstance = 'H2O';
            tParameters.sProperty = 'Pressure';
            tParameters.sFirstDepName = 'Density';
            tParameters.fFirstDepValue = fDensityLiquid_Y;
            tParameters.sPhaseType = 'liquid';
            tParameters.sSecondDepName = 'Temperature';
            tParameters.fSecondDepValue = fTemperatureLiquidOld;
            tParameters.bUseIsobaricData = false;
            
            fPressureLiquid_Y = this.oMT.findProperty(tParameters);
            fErrorStore_Y = fPressureGas_Y-fPressureLiquid_Y;
            
            % If the signs are identical the search intervall is increased.
            % Depending on wether the sign is positive or negative the left
            % or right border for the search intervall is moved
            if sign(fErrorStore_X) == sign(fErrorStore_Y) && sign(fErrorStore_Y) == 1
                fVolumeGas_Y = fVolumeGas_Y + (10*(abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow)) + abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow))));
            elseif sign(fErrorStore_X) == sign(fErrorStore_Y) && sign(fErrorStore_X) == -1
                fVolumeGas_X = fVolumeGas_X - (10*(abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow)) + abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow))));
            end
            counter1 = counter1 + 1;
        end
        
        fErrorStore = fErrorStore_Y;
        
        counter1 = 1;
        
        if abs(fErrorStore_Y) <= 10^-5
            fVolumeGasNew = fVolumeGas_Y;
            fVolumeLiquidNew = this.fVolume-fVolumeGas_Y;
        end
        
        while abs(fErrorStore) > 10^-5 && counter1 <= 500
            
            fVolumeGas1_Z = fVolumeGas_X+((fVolumeGas_Y-fVolumeGas_X)/2);
            
            if (fVolumeGas1_Z - fVolumeGas_X) == 0
                % In this case the numerical accuracy is reached and a more
                % accurate result is not possible.
                counter1 = 600;
            end
            
            fDensityLiquid_X = fMassLiquid/(this.fVolume-fVolumeGas_X);
            fDensityLiquid_Z = fMassLiquid/(this.fVolume-fVolumeGas1_Z);
            
            fPressureGas_X  = (fMassGas*fR*fTemperatureGasOld)/(fMolarMassGas*fVolumeGas_X);
            fPressureGas1_Z = (fMassGas*fR*fTemperatureGasOld)/(fMolarMassGas*fVolumeGas1_Z);
            
            %TODO Replace this with a calculatePressure() method in the
            %matter table that takes all contained substances into account,
            %not just water.
            tParameters = struct();
            tParameters.sSubstance = 'H2O';
            tParameters.sProperty = 'Pressure';
            tParameters.sFirstDepName = 'Density';
            tParameters.fFirstDepValue = fDensityLiquid_X;
            tParameters.sPhaseType = 'liquid';
            tParameters.sSecondDepName = 'Temperature';
            tParameters.fSecondDepValue = fTemperatureLiquidOld;
            tParameters.bUseIsobaricData = false;
            
            fPressureLiquid_X = this.oMT.findProperty(tParameters);
            
            %TODO Replace this with a calculatePressure() method in the
            %matter table that takes all contained substances into account,
            %not just water.
            tParameters = struct();
            tParameters.sSubstance = 'H2O';
            tParameters.sProperty = 'Pressure';
            tParameters.sFirstDepName = 'Density';
            tParameters.fFirstDepValue = fDensityLiquid_Z;
            tParameters.sPhaseType = 'liquid';
            tParameters.sSecondDepName = 'Temperature';
            tParameters.fSecondDepValue = fTemperatureLiquidOld;
            tParameters.bUseIsobaricData = false;
            
            fPressureLiquid1_Z = this.oMT.findProperty(tParameters);
            
            fErrorStore_X = fPressureGas_X-fPressureLiquid_X;
            fErrorTank1_Z = fPressureGas1_Z-fPressureLiquid1_Z;
            fErrorStore = fErrorTank1_Z;
            
            if fErrorTank1_Z == 0
                counter1 = inf;
            elseif sign(fErrorTank1_Z) == sign(fErrorStore_X)
                fVolumeGas_X = fVolumeGas1_Z;
            else
                fVolumeGas_Y = fVolumeGas1_Z;
            end
            
            counter1 = counter1+1;
            
            if abs(fErrorStore_Y) > 10^-5
                fVolumeGasNew = fVolumeGas1_Z;
                fVolumeLiquidNew = this.fVolume-fVolumeGas1_Z;
            end
        end
        
        for k = 1:length(this.aoPhases)
            if strcmp(this.aoPhases(k).sType, 'gas')
                this.aoPhases(k).setVolume(fVolumeGasNew);
            end
            
            if strcmp(this.aoPhases(k).sType, 'liquid')
                this.aoPhases(k).setVolume(fVolumeLiquidNew);
            end
        end
        
        this.fTotalPressureErrorStore = this.fTotalPressureErrorStore+fErrorStore;
        this.iNestedIntervallCounterStore = counter1;
    end
end



if ~base.oLog.bOff, this.out(1, 1, 'store-update', 'UPDATE store %s-%s and set last update!', { this.oContainer.sName, this.sName }); end


% Update phases
for iI = 1:this.iPhases, this.aoPhases(iI).update(); end

% Update stationary P2P processors
for iP = this.aiProcsP2Pstationary
    this.toProcsP2P.(this.csProcsP2P{iP}).update();
end

this.fLastUpdate = this.oTimer.fTime;
this.fNextExec   = inf;
end