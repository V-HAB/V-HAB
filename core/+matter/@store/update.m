function update(this, ~)
%UPDATE Updates the phases inside this store
% Update phases, then recalculate internal values as volume
% available for phases.

this.fTimeStep   = this.fDefaultTimeStep;

% Set the default time step - can be overwritten by phases
this.setTimeStep(this.fTimeStep);

%%
% calculates the volume of liquid and gas phase if both phases are present
% in one store.
if ~this.bNoStoreCalculation
    % Currently only works if at most one of each phase type is
    % present!
    if length(this.aiLiquidPhases) > 1 || length(this.aiSolidPhases) > 1
        error('the calculation for more than one phase of a specific type was not yet implemented. Please use only one gas/solid/liquid phase at a time')
    end
    
    % If there are liquid and solid phases, calculate their density and
    % from that their volume with the old pressure
    if ~isempty(this.aiLiquidPhases)
        fLiquidDensity = this.oMT.calculateDensity(this.aoPhases(this.aiLiquidPhases));
        fVolumeLiquid = this.aoPhases(this.aiLiquidPhases).fMass / fLiquidDensity;
    else
        fVolumeLiquid = 0;
    end
    if ~isempty(this.aiSolidPhases)
        fSolidDensity = this.oMT.calculateDensity(this.aoPhases(this.aiSolidPhases));
        fVolumeSolid = this.aoPhases(this.aiSolidPhases).fMass / fSolidDensity;
    else
        fVolumeSolid = 0;
    end
    if (this.fVolume - (fVolumeLiquid + fVolumeSolid)) < 0
        error('the time step was too large and the calculate liquid volume in store %s became smaller than zero', this.sName)
    end
    
    % If there are gas phases calculate the remaining volume in the store
    % and use that as new gas volume. Then calculate the new gas pressure
    % and set those values.
    if ~isempty(this.aiGasePhases)
        fVolumeGas = this.fVolume - (fVolumeLiquid + fVolumeSolid);
        
        % It is possible that negative values occur if too much liquid was
        % allowed to flow into the store, or too much solid was added! If
        % that happens we tell the user to decrease the time step of the
        % store or provide another limitation (e.g. use exec to limit
        % liquid volume)
        if fVolumeGas < 0
            error('the time step was too large and the calculate gas volume in store %s became smaller than zero', this.sName)
        end
        
        iGasPhases = length(this.aiLiquidPhases);
        
        this.aoPhases(this.aiGasePhases).setVolume(fVolumeGas / iGasPhases);
        
        mfGasPressure = zeros(1,iGasPhases);
        for iGasPhase = 1:iGasPhases
            % p*V = m*R*T => p = m*R*T / V
            oGas = this.aoPhases(this.aiGasePhases(iGasPhase));
            mfGasPressure(iGasPhase) = oGas.fMass * (this.oMT.Const.fUniversalGas/oGas.fMolarMass) * oGas.fTemperature / oGas.fVolume;
        end
        
        % Since currently only one liquid/solid phase is allowed with store
        % calculations, we use the average pressure. Otherwise it is also
        % difficult to know which gas phase represents which liquid phase
        % etc.
        fPressure = sum(mfGasPressure) / iGasPhases;
        
        % If a liquid is present we now tell the liquid its new pressure
        % and volume!
        if ~isempty(this.aiLiquidPhases)
            this.aoPhases(this.aiLiquidPhases).setVolume(fVolumeLiquid);
            this.aoPhases(this.aiLiquidPhases).setPressure(fPressure);
        end
    else
        % No gas phase, only set the pressure of the liquid phase
        if ~isempty(this.aiLiquidPhases)
            
            error('The calculation of compressible liquids is not yet implemented in V-HAB, you must use a gas phase together with the liquid!')
            % The calculatepressure function of the matter table does not
            % match the values of the calculateDensity function, which is a
            % currently open issue in gitlab (#80=
%             fPressure = this.oMT.calculatePressure(this.aoPhases(this.aiLiquidPhases));
%             this.aoPhases(this.aiLiquidPhases).setPressure(fPressure);
        else
            % if also no liquid is present we cannot calculate a pressure
            return
        end
    end
    % In case that a solid was present and either a gas or liquid (or both)
    % is also in the store, we set the pressure and volume of the solid now
    if ~isempty(this.aiSolidPhases)
        this.aoPhases(this.aiSolidPhases).setVolume(fVolumeSolid);
        this.aoPhases(this.aiSolidPhases).setPressure(fPressure);
    end
end



if ~base.oDebug.bOff, this.out(1, 1, 'store-update', 'UPDATE store %s-%s and set last update!', { this.oContainer.sName, this.sName }); end


% Update phases
for iI = 1:this.iPhases, this.aoPhases(iI).registerUpdate(); end

% Update stationary P2P processors
for iP = this.aiProcsP2Pstationary
    this.toProcsP2P.(this.csProcsP2P{iP}).update();
end

this.fLastUpdate = this.oTimer.fTime;
this.fNextExec   = inf;
end