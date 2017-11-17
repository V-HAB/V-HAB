classdef store < base
    %STORE Summary of this class goes here
    %   Detailed explanation goes here
    %
    %TODO
    %   - see comments at fVolume; also: creating new phases, what volume
    %     to set? should basically immediately derive from store, never
    %     directly be provided, right?
    %   - something like total pressure, if gas phases share a volume?
    
    properties (SetAccess = private, GetAccess = public)
        % Phases - mixin arrays, with the base class being matter.phase who
        % is abstract - therefore can't create empty - see matter.table ...
        % @type array
        % @types object
        aoPhases = [];
        
        toPhases = struct();
        
        % Amount of phases
        iPhases;
        
        % Processors - p2p (int/exme added to phase, f2f to container)
        toProcsP2P = struct(); %matter.procs.p2p.empty();
        
        % @type cell
        % @types string
        %TODO This property should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        csProcsP2P = {};
        
        %TODO This property should be transient. That requires a static
        % method (loadobj) to be implemented in this class, so when the
        % simulation is re-loaded from a .mat file, the properties are
        % reset to their proper values.
        aiProcsP2Pstationary;
        
        % Matter table
        % @type object
        oMT;
        
        % Reference to the vsys (matter.container) in which this store is 
        % contained
        oContainer;
        
        % Name of store
        % @type string
        sName;
        
        % If the initial configuration of the store and all its phases,
        % processors, stuff bluff blah is done - seal it, so no more phases
        % can be added to the store, no more port/exmes can be added to the
        % phases, no more MFs to the exme's (some interfaces flows that are
        % specificly defined can still be reconnected later, nothing else,
        % and they can only be connected to an interface branch of the
        % superior system)
        bSealed = false;
        
        %%
        %This is only important for gravity or likewise driven systems 
        %where the position of ports and geometry of the store is no longer
        %insignifcant.
        %Geometry struct of the store with the possible inputs: (atm only
        %Box shape)
        % tGeometryParameters = struct('Shape', 'Box', 'Area', 0.5, 'HeightExMe', 0.5)
        %   "Box"       : Could be a rectangular shaped store or a zylinder
        %                 with its axis congruent to the acceleration
        tGeometryParameters = struct('Shape','Box', 'Area', 1, 'HeightExMe', 0);        

        
        %%
        % Timer object, needs to inherit from / implement event.timer
        oTimer;
        fLastUpdate = 0;
        fTimeStep = 0;
        fNextExec = inf;
        
        fTotalPressureErrorStore = 0;
        iNestedIntervallCounterStore = 0;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Volume. Can be set through setVolume, subtracts volumes of fluid
        % and solid phases and distributes the rest equally throughout the
        % gas phases.
        %
        %TODO could be dependent on e.g. some geom.cube etc. If volume of a
        %     phase changes, might be some 'solved' process due to
        %     available vol energy for vol change - properties of phase
        %     (gas isochoric etc, solids, ...). Does not necessarily change
        %     store volume, but if store volume is reduced, the phase vol
        %     change things have to be taken into account.
        % @type float
        fVolume = 0;
        
        %Parameter to check wether liquids should be calculated as
        %compressible or incompressible compared to gas phases in the store
        bIsIncompressible = 1;
    end
    
    properties (SetAccess = protected, GetAccess = protected)
        setTimeStep;
    end
    
    properties (SetAccess = public, GetAccess = public)
        % When store executes, this is set as the default time step. Any of
        % the phases can set a lower one.
        fDefaultTimeStep = 60;
    end
    
    
    methods
        function this = store(oContainer, sName, fVolume, bIsIncompressible, tGeometryParams)
            % Create a new matter store object. Expects the matter table
            % object and a name as parameters. Optionally, you can pass a
            % store volume and whether the contents of the store are
            % compressible. For compressible fluids in a non-zero-G
            % environment, a fifth parameter with geometric parameters can
            % be passed.
            
            this.sName      = sName;
            this.oContainer = oContainer;
            
            % Add this store object to the matter.container
            this.oContainer.addStore(this);
            
            this.oMT    = this.oContainer.oRoot.oMT;
            this.oTimer = this.oContainer.oRoot.oTimer;
            
            
            if nargin >= 3
                this.fVolume = fVolume;
            end
            if nargin >= 4
                this.bIsIncompressible = bIsIncompressible;
            end
            if nargin >= 5
                this.tGeometryParameters = tGeometryParams;
            end
            
        end
        
        
        function exec(this)
            %TODO-NOW this.toProcsP2P exec, flow and stationary.
            %this.throw('exec', 'Not implemented!');
        end
        
        function update(this, ~)
            % Update phases, then recalculate internal values as volume
            % available for phases.
            %
            %TODO don't update everything all the time? If one phase
            %     changes, do not necessarily to update all other phases as
            %     well? If liquid, need to update gas, but other way
            %     around?
            %     First update solids, then liquids, then gas?
            %     Smarter ways for volume distribution?
            
            this.fTimeStep   = this.fDefaultTimeStep;
            
            % Set the default time step - can be overwritten by phases
            %TODO register post-post-tick-callback and only set then?
            this.setTimeStep(this.fTimeStep);
            
            %TODO check volume stuff
            
            %%
            %calculates the volume of liquid and gas phase if both phases
            %are present in one store
            
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
                    
                    %the left and right border for the search intervall are
                    %calculated (The if query has to be so long and
                    %calculate with abs() because the place where the
                    %values are added/subtracted changes depending on their
                    %direction)
                    if sum(mFlowRateLiquid) > 0 && sum(mFlowRateGas) == 0
                        %for no gas flows and a positiv liquid flow the
                        %lower volume boundary can be defined by
                        %subtracting the volume of water that flowed into
                        %the store from the old gas volume while assuming
                        %the liquid to be incompressible
                        fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
                        %the higher volume boundary is simply the old gas
                        %volume
                        fVolumeGas_Y = fVolumeGasOld;
                        
                    elseif sum(mFlowRateLiquid) < 0 && sum(mFlowRateGas) == 0
                        %for no gas flows and a negativ liquid flow the
                        %lower volume boundary is simply the old gas
                        %volume
                        fVolumeGas_X = fVolumeGasOld;
                        %the higher volume boundary can be defined by
                        %adding the volume of water that flowed out of 
                        %the store to the old gas volume while assuming
                        %the liquid to be incompressible
                        fVolumeGas_Y = fVolumeGasOld  + abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
                        
                    elseif sum(mFlowRateGas) > 0 && sum(mFlowRateLiquid) == 0
                        %for no liquid flow and a positiv gas flow the
                        %lower volume boundary is simply the old gas volume
                        fVolumeGas_X = fVolumeGasOld;
                        %the higher volume boundary can be defined by
                        %adding the volume of gas that flowed into the
                        %store to the old gas volume assuming the volume
                        %flow to be incompressible
                        fVolumeGas_Y = fVolumeGasOld  + abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow));
                        
                    elseif sum(mFlowRateGas) < 0 && sum(mFlowRateLiquid) == 0
                        mDensityGasFlow = (fR*mTemperatureGasFlow)/(fMolarMassGas*mPressureGasFlow);
                        %for no liquid flow and a negativ gas flow the
                        %lower volume boundary can be defined by
                        %subtracting the volume of gas that flowed into the
                        %store to the old gas volume assuming the volume
                        %flow to be incompressible
                        fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow));
                        %the higher volume boundary is simply the old gas 
                        %volume
                        fVolumeGas_Y = fVolumeGasOld;
                        
                    elseif sum(mFlowRateLiquid) >= 0 && sum(mFlowRateGas) >= 0
                        %in the case that both flow are positive the lower
                        %volume boundary can be defined by subtracting the 
                        %incompressible volumeflow of water from the old gas
                        %volume
                        fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
                        %the higher volume boundary can be defined by
                        %adding the incompressible volumeflow of gas into
                        %the tank to the old gas volume
                        fVolumeGas_Y = fVolumeGasOld + abs((fTimeStepVolume*mFlowRateGas)/mDensityGasFlow);
                        
                    elseif sum(mFlowRateLiquid) < 0 && sum(mFlowRateGas) >= 0
                        %in the case that the liquid flow is negative and 
                        %the gas flow positive the lower volume boundary 
                        %is simply the old gas volume
                        fVolumeGas_X = fVolumeGasOld;
                        %the higher volume boundary can be defined by
                        %adding the incompressible volumeflow of gas into
                        %the tank to the old gas volume and subtracting the
                        %incompressible water flow from the tank as well
                        fVolumeGas_Y = fVolumeGasOld + abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow))  - abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
                        
                 	elseif sum(mFlowRateLiquid) >= 0 && sum(mFlowRateGas) < 0
                        %in the case that the liquid flow is positive and 
                        %the gas flow  negative the lower volume boundary 
                        %can be defined by subtracting the incompressible 
                        %volumeflow of gas into the tank from the old gas 
                        %volume and subtracting the incompressible water 
                        %flow from the tank as well
                        fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow))  - abs(sum((fTimeStepVolume*mFlowRateLiquid)./mDensityLiquidFlow));
                        %the higher volume boundary is simply the old gas
                        %volume
                        fVolumeGas_Y = fVolumeGasOld;
                        
                 	elseif sum(mFlowRateLiquid) < 0 && sum(mFlowRateGas) < 0
                        %in the case that both flow are negative the lower
                        %volume boundary can be defined by subtracting the 
                        %incompressible volumeflow of gas from the old gas
                        %volume
                        fVolumeGas_X = fVolumeGasOld - abs(sum((fTimeStepVolume*mFlowRateGas)./mDensityGasFlow));
                        %the higher volume boundary can be defined by
                        %adding the incompressible volumeflow of water into
                        %the tank to the old gas volume
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
                    %if the two borders do not contain the zepoint it is 
                    %necessary to shift the borders until they contain it
                    while sign(fErrorStore_X) == sign(fErrorStore_Y) && counter1 <= 500
                        fDensityLiquid_X = fMassLiquid/(this.fVolume-fVolumeGas_X);
                        fPressureGas_X = (fMassGas*fR*fTemperatureGasOld)/(fMolarMassGas*fVolumeGas_X);
                        
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

                        %if the signs are identical the search intervall is
                        %increased. Depending on wether the sign is positive or
                        %negative the left or right border for the search
                        %intervall is moved
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
                            %in this case the numerical accuracy is reached
                            %and a more accurate result is not possible.
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
            
            
            
            if ~base.oLog.bOff, this.out(1, 1, 'store-update', 'UPDATE store %s-%s and set last update!', { this.oContainer.sName, this.sName }); end;
            
            
            % Update phases
            for iI = 1:this.iPhases, this.aoPhases(iI).update(); end;

            % Update stationary P2P processors
            for iP = this.aiProcsP2Pstationary
                this.toProcsP2P.(this.csProcsP2P{iP}).update();
            end
            
            this.fLastUpdate = this.oTimer.fTime;
            this.fNextExec   = inf;
        end
        
        %CHECK Can this method be deleted?
        function setNextUpdateTime(this, fTime)
            % Set a time step for updating the store and all phases. Only
            % sets shorter times for updating!
            % IMPORTANT - parameter does NOT define next time step but the 
            %             next ABSOLUTE time this store is updated.
            
            this.throw('setNextUpdateTime', 'Use setNextTimeStep(fTimeStep) instead! Measured from the current point in time!');
            
            % Check if last update time (same as the one stored within the
            % timer) plus current time step larger then new exec time - if
            % yes, calc the new time step with fTime and set!
            %TODO should timer somehow always provide the last exec time
            %     for each subsystem, on each callback execution?
            if (this.fLastUpdate + this.fTimeStep) > fTime
                this.fTimeStep = fTime - this.fLastUpdate;
                
                if ~base.oLog.bOff, this.out(1, 1, 'set-new-ts', 'New TS in Store %s-%s: %.16f s - Next Exec: %.16f s', { this.oContainer.sName, this.sName, this.fTimeStep, this.fLastUpdate + this.fTimeStep }); end;
                
                % If time step < 0, timer sets it to 0!
                this.setTimeStep(this.fTimeStep);
                %disp([ this.sName '  ' num2str(this.oTimer.iTick) '  ' num2str(this.fTimeStep) ]);
            else
                %keyboard();
                %disp([ this.sName '  ' num2str(this.oTimer.iTick) '   SAME   ' num2str(this.fTimeStep) ]);
            end
        end
        
        
        
        
        function setNextTimeStep(this, fTimeStep)
            % This method is called from the phase object during its
            % calculation of a new timestep. The phase.calculateTimeStep()
            % method is called in the post-tick of every mass update (NOT
            % phase update!). Within a tick, the first thing that is done,
            % is the calling of store.update(). This sets the fTimeStep
            % property of the store to the default time step (currently 60
            % seconds). After that the phases are updated, which also calls
            % calculateTimeStep(). In this function
            % (store.setNextTimeStep()), the store's time step is only set,
            % if the phase time step is smaller than the currently set time
            % step. This ensures, that the slowest phase sets the time step
            % of the store it is in. 
            
            % So we will first get the next execution time based on the
            % current time step and the last time this store was updated.
            %fCurrentNextExec = this.fLastUpdate + this.fTimeStep;
            
            % Since the fTimeStep parameter that is passed on by the phase
            % that called this method is based on the current time, we
            % calculate the potential new execution time based on the
            % timer's current time, rather than the last update time for
            % this store.
            fNewNextExec     = this.oTimer.fTime + fTimeStep;
            
            if ~base.oLog.bOff, this.out(1, 1, 'check-set-new-ts', 'Set new TS in store %s-%s ?? Current Next Exec: %.16f s - New next Exec: %.16f s - New Time Step: %.16f s', { this.oContainer.sName, this.sName, this.fNextExec, fNewNextExec, fTimeStep }); end;
            
            % Now we can compare the current next execution time and the
            % potential new execution time. If the new execution time would
            % be AFTER the current execution time, it means that the phase
            % that is currently calling this method is faster than a
            % previous caller. In this case we do nothing and just return.
            if this.fNextExec <= fNewNextExec
                return;
            end
            
            if ~base.oLog.bOff, this.out(1, 1, 'set-new-ts', 'New TS in Store %s-%s: %.16f s - Next Exec: %.16f s', { this.oContainer.sName, this.sName, fTimeStep, fNewNextExec }); end;
            
            % The new time step is smaller than the old one, so we can
            % actually set then new timestep. The setTimeStep() method
            % calls a function in the timer object that will update the
            % timer values accordingly. This is important because otherwise
            % the time step updates that happen during post-tick operations
            % would not be taken into account when the timer calculates the
            % overall time step during the next tick.
            this.setTimeStep(fTimeStep, true);
            
            % Finally we set this stores fTimeStep property to the new time
            % step.
            this.fTimeStep = fTimeStep;
            this.fNextExec = this.oTimer.fTime + this.fTimeStep;
        end
    end
    
    
    %% Methods for the outer interface - manage ports, volume, ...
    methods
        function oProc = getPort(this, sPort)
            % Check all phases to find port
            %
            % If two phases have the same port (except 'default'), for now
            % trigger error, later implement functionality to handle that?
            % -> e.g. water tank - port could deliver water or air depen-
            %    ding on fill level - flow needs to cover two phases.
            %    Something like linked flows, diameter in MFs distriuted
            %    accordingly: D[iam] - D(solids, fluids) = D_available(gas)
            %
            %NOTE on adding phases and their ports, it has to be made sure
            %     that no port of any phase has the same name then one of
            %     the phases themselves.
            %
            %TODO 
            %   - throw an error if the port was found on several phases?
            %   - create index in seal() of phases and their ports!
            
            % Find out if default port of a phase should be used
            %TODO check for empty aoPhases ...
            %TODO throw out! Default ports will be removed anyways. Right
            %     now a port can't have the same name than a phase!
            iIdx = find(strcmp({ this.aoPhases.sName }, sPort), 1);
            
            if ~isempty(iIdx)
                sPort  = 'default';
            else
                %TODO make waaaay better!!
                for iI = 1:length(this.aoPhases)
                    if isfield(this.aoPhases(iI).toProcsEXME, sPort)
                        iIdx = iI;
                        
                        break;
                    end
                end
            end
            
            if isempty(iIdx) || ~isfield(this.aoPhases(iIdx).toProcsEXME, sPort)
                this.throw('getPort', 'Port %s could not be found', sPort);
            end
            
            oProc = this.aoPhases(iIdx).toProcsEXME.(sPort);
        end
        
        function this = addPhase(this, oPhase)
            % Adds a phase to a store. If phase already has a store set,
            % throws an error.
            
            
            if this.bSealed
                this.throw('addPhase', 'The store is sealed, so no phases can be added any more.');
            end
            
            if ~isempty(this.aoPhases) && any(strcmp({ this.aoPhases.sName }, oPhase.sName))
                this.throw('addPhase', 'Phase with such a name already exists!');
                
            elseif ~isempty(oPhase.oStore) && (oPhase.oStore ~= this)
                this.throw('addPhase', 'Can only add phases that do not have a parent oStore set (i.e. just while constructing)!');
            
            else
                if isempty(this.aoPhases), this.aoPhases          = oPhase;
                else                       this.aoPhases(end + 1) = oPhase;
                end
                
                this.toPhases.(oPhase.sName) = oPhase;
            end
        end
        
        
        function oPhase = createPhase(this, sHelper, varargin)
            % Creates an instance of a matter phase with the use of a
            % helper method.
            
            if this.bSealed
                this.throw('createPhase', 'The store is sealed, so no phases can be added any more.');
            end
            
            %CHECK provide fVolume to helper automatically if varargin
            %      empty - should be required most of the time right?
            if isempty(varargin), varargin = { this.fVolume }; end;

            % Get params and default 
            [ cParams, sDefaultPhase ] = this.createPhaseParams(sHelper, varargin{:});
            
            % Function handle from phase class path and create object
            hClassConstr = str2func(sDefaultPhase);
            oPhase       = hClassConstr(cParams{:});
        end
        
        
        
        
        function seal(this)
            % See doc for bSealed attr.
            %
            %TODO create indices of phases, their ports etc! Trigger event?
            %     -> external solver can build stuff ... whatever, matrix,
            %        function handle cells, indices ...
            %     also create indices for amount of phases, in phases for
            %     amount of ports etc
            
            if this.bSealed, return; end;
            
            
            
            % Bind the .update method to the timer, with a time step of 0
            % (i.e. smallest step), will be adapted after each .update
            %this.setTimeStep = this.oTimer.bind(@(~) this.update(), 0);
            this.setTimeStep = this.oTimer.bind(@this.update, 0, struct(...
                'sMethod', 'update', ...
                'sDescription', 'The .update method of a store (i.e. including phases)', ...
                'oSrcObj', this ...
            ));
            
            
            this.iPhases    = length(this.aoPhases);
            this.csProcsP2P = fieldnames(this.toProcsP2P);
            
            % Find stationary p2ps
            %TODO split those up completely, stationary/flow p2ps?
            for iI = 1:length(this.csProcsP2P)
                if isa(this.toProcsP2P.(this.csProcsP2P{iI}), 'matter.procs.p2ps.stationary')
                    this.aiProcsP2Pstationary(end + 1) = iI;
                end
            end
            
            
            % Update volume on phases
            this.setVolume();
            
            
            % Seal phases
            for iI = 1:length(this.aoPhases)
                this.aoPhases(iI).seal(); 
            end
            
            this.bSealed = true;
        end
        
        
        
        
        
        function addP2P(this, oProcP2P)
            % Get sName from oProcP2P, add to toProcsP2P
            %
            %TODO better way of handling stationary and flow p2ps!
            
            if this.bSealed
                this.throw('addP2P', 'Store already sealed!');
            elseif isfield(this.toProcsP2P, oProcP2P.sName)
                this.throw('addP2P', 'P2P proc already exists!');
            elseif this ~= oProcP2P.oStore
                this.throw('addP2P', 'P2P proc does not have this store set as parent store!');
            end
            
            this.toProcsP2P.(oProcP2P.sName) = oProcP2P;
        end
    end
    
    
    
    %% Internal methods for handling of table, phases, f2f procs %%%%%%%%%%
    methods (Access = protected)
        function setVolume(this, fVolume)
            % Change the volume.
            %
            %TODO Event?
            % Trigger 'set.fVolume' -> return values of callbacks say
            % something about the distribution throughout the phases?
            % Then trigger 'change.fVolume'?
            % Don't change if no callback registered for set.fVol or do
            % some default stuff then?
            %tRes = this.trigger('set.fVolume', fVolume);
            % Somehow process tRes ... how? Multiple callbacks possible?
            % Which wins?? Just distribution of volumes for gas/plasma, or
            % also stuff to change e.g. solid volumes (waste compactor)?
            %
            % Also: several gases in one phase - pressures need to be added
            % to get the total pressure.
            
            %TODO in .seal(), store the references to solid/liquid/gas/...?
            
            % Mabye just for update
            if nargin >= 2, this.fVolume = fVolume; end;
            
            % Update ...
            csVolPhases  = { 'solid', 'liquid', 'absorber', 'mixture'};
            iPhasesSet   = 0;
            fVolume      = this.fVolume;
            
            % Go through phases, subtract volume of solid/fluid phases and
            % count the gas/plasma phases
            for iI = 1:this.iPhases
                if any(strcmp(csVolPhases, this.aoPhases(iI).sType))
                    fVolume = fVolume - this.aoPhases(iI).fVolume;
                    
                else
                    iPhasesSet = iPhasesSet + 1;
                end
            end
            
            % Check if the user has entered values for the solid, liquid or
            % absorber phase volumes that are larger than the store's. If
            % so, throw an error. 
            if tools.round.prec(fVolume, this.oTimer.iPrecision) < 0
                this.throw('The values you have entered for the phase volumes of the ''%s'' store are larger than the store itself.', this.sName);
            end
            
            % Set remaining volume for each phase - see above, need to
            % calculate an absolute pressure from all gas/plasma phases?
            for iI = 1:this.iPhases
                if ~any(strcmp(csVolPhases, this.aoPhases(iI).sType))
                    this.aoPhases(iI).setVolume(fVolume);
                end
            end
        end
        
        
        function setMatterTable(this, oMT)
            % Set matter table for store, also updates phases (and p2p?)
            %
            %TODO update p2p procs MT?
            
            if ~isa(oMT, 'matter.table'), this.throw('setMatterTable', 'Provided object ~isa matter.table'); end;
            
            this.oMT = oMT;
            
            % Call setMatterTable on the phases
            if ~isempty(this.aoPhases), this.aoPhases.updateMatterTable(); end;
            
            % Procs P2P
            csProcs = fieldnames(this.toProcsP2P);
            
            for iI = 1:length(csProcs)
                this.toProcsP2P.(csProcs{iI}).updateMatterTable();
            end
        end
        
        function [ cParams, sDefaultPhase ] = createPhaseParams(this, sHelper, varargin)
            % Returns a (row) cell with at least the first two parameters 
            % for the constructor of a phase class. First field is a refe-
            % rence  to this matter table, second the composition of the 
            % mass (struct with field names being the matter types). Depen-
            % ding on the helper, additional fields might be returned.
            %
            % create Parameters:
            %   sHelper     - Name of the helper in matter.helper.create.*
            %   varargin    - Possibly optional, paramters for the helper
            %
            % create Returns:
            %   cParams     - parameters for the phase constructor
            %   sPhaseName  - path (with package) to the according class,
            %                 only returned if requested
            
            % If the first item of varargin is a string, then it is a
            % user-provided name for the phase to be created. If it is
            % anything else, it is one of the parameters.
            if ischar(varargin{1})
                sPhaseName   = varargin{1};
                cPhaseParams = varargin(2:end);
            else
                sPhaseName = [this.sName, '_Phase_', num2str(length(this.aoPhases)+1)];
                cPhaseParams = varargin; 
            end
            
            % Check if the calling code (this.create() or external)
            % requests two outputs - also need to provide the name of the
            % phase class
            if nargout > 1
                % Helper needs to support two function outputs!
                if nargout(str2func([ 'matter.helper.phase.create.' sHelper ])) < 2
                    this.throw('createPhaseparams', 'Helper %s does not support to return a default phase class path.', sHelper);
                end
                [ cParams, sDefaultPhase ] = matter.helper.phase.create.(sHelper)(this, cPhaseParams{:});
            else
                cParams       = matter.helper.phase.create.(sHelper)(this, cPhaseParams{:});
                sDefaultPhase = '';
            end
            
            % The name of the phase will be automatically the helper name!
            % If that should be prevented, createPhaseParams has to be used
            % directly and phase constructor manually called.
            cParams = [ { this sPhaseName } cParams ];
            %cParams = { this sHelper cParams{:} };
        end
        
        
        
        
    end
    
end

