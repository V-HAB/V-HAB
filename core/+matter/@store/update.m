function update(this, ~)
%UPDATE Updates the phases inside this store
% Update phases, then recalculate internal values as volume
% available for phases.

this.fTimeStep   = this.fDefaultTimeStep;

% Set the default time step - can be overwritten by phases
this.setTimeStep(this.fTimeStep);

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