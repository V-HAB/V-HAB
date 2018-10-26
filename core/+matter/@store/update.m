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

aiGasePhases = [];
aiLiquidPhases = [];
aiSolidPhases = [];
for iPhase = 1:length(this.aoPhases)
    if strcmp(this.aoPhases(iPhase).sType, 'gas')
        aiGasePhases(end+1) = iPhase; %#ok
    elseif strcmp(this.aoPhases(iPhase).sType, 'liquid')
        aiLiquidPhases(end+1) = iPhase; %#ok
    elseif strcmp(this.aoPhases(iPhase).sType, 'solid')
        aiSolidPhases(end+1) = iPhase; %#ok
    end
end

if this.bIsIncompressible == 0
    
    fLiquidDensity = this.oMT.calculateDensity(this.aoPhases(aiLiquidPhases));
    fVolumeLiquid = this.aoPhases(aiLiquidPhases).fMass / fLiquidDensity;
    
    if ~isempty(aiSolidPhases)
        fSolidDensity = this.oMT.calculateDensity(this.aoPhases(aiSolidPhases));
        fVolumeSolid = this.aoPhases(aiSolidPhases).fMass / fSolidDensity;
    else
        fVolumeSolid = 0;
    end
    
    if ~isempty(aiGasePhases)
        fVolumeGas = this.fVolume - (fVolumeLiquid + fVolumeSolid);

        this.aoPhases(aiGasePhases).setVolume(fVolumeGas);
        
        % p*V = m*R*T => p = m*R*T / V
        oGas = this.aoPhases(aiGasePhases);
        fPressure = oGas.fMass * (this.oMT.Const.fUniversalGas/oGas.fMolarMass) * oGas.fTemperature / oGas.fVolume;
    else
        fPressure = this.oMT.calculatePressure(this.aoPhases(aiLiquidPhases));
    end
    
    this.aoPhases(aiLiquidPhases).setVolume(fVolumeLiquid);
    this.aoPhases(aiLiquidPhases).setPressure(fPressure);
    
    if ~isempty(aiSolidPhases)
        this.aoPhases(aiSolidPhases).setVolume(fVolumeSolid);
        this.aoPhases(aiSolidPhases).setPressure(fPressure);
    end
end



if ~base.oLog.bOff, this.out(1, 1, 'store-update', 'UPDATE store %s-%s and set last update!', { this.oContainer.sName, this.sName }); end


% Update phases
for iI = 1:this.iPhases, this.aoPhases(iI).registerUpdate(); end

% Update stationary P2P processors
for iP = this.aiProcsP2Pstationary
    this.toProcsP2P.(this.csProcsP2P{iP}).update();
end

this.fLastUpdate = this.oTimer.fTime;
this.fNextExec   = inf;
end