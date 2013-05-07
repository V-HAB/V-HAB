classdef exme < base
    %EXME extract/merge processor
    %   Extracts matter flow from and merges matter flow into a phase.
    %
    % See also matter.procs.f2f which has a lot in common.
    %
    %TODO
    %   - for specific solvers, probably need additional methods. So either
    %     user needs to know solver and includes according EXME, or need
    %     some kind of proxy/decorator that the solver uses and places 'in
    %     front of' the actual EXME ...?
    %     Or similar to .setAttribute here, use function handles, maybe
    %     provided with some func handles from EXME/Flows/Branches/...?
    %   - exme/f2f same base class? also p2p?
    
    properties (SetAccess = private, GetAccess = private)
        % See matter.proc.f2f
        pthFlow;
    end
    
    %TODO check - protected, private access? Ok that derived can set any
    %     value? More generic extract(), merge() here?
    properties (SetAccess = private, GetAccess = protected)
        
        % Function handle to the phase to set any attribute!
        setAttribute;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Phase the EXME belongs to
        oPhase;
        
        % Matter table
        oMT;
        
        % Name of processor. If 'default', several MFs can be connected
        %TODO make that configurable?
        sName;
        
        % Connected matter flows
        aoFlows = matter.flow.empty();
        
        % See @matter.procs.f2f
        aiSign;
        
        
        % Store in .extract for later use
        arPartials;
    end
    
    
    
    methods
        function this = exme(oPhase, sName)
            % Constructor for the exme matter processor class. 
            % oPhase is the phase the exme is attached to
            % sName is the name of the processor
            % Used to extract / merge matter from / into phases. Default
            % functionality is just merging of enthalpies based on ideal
            % conditions and extraction with the according matter
            % properties and no "side effects".
            % For another behaviour, derive from that proc and overload the
            % .extract or .merge method.
            
            this.sName  = sName;
            this.oMT    = oPhase.oMT; % put in updateMT, has to be called by phase if MT changes
            
            this.setAttribute = oPhase.addProcEXME(this);
            
            this.oPhase = oPhase;
            
            
            
            % Create map for the func handles
            this.pthFlow = containers.Map('KeyType', 'single', 'ValueType', 'any');
        end
        
        function update(this, fTimeStep, sType)
            
            afFRs = this.getFRs();
            
%             if strcmp(this.oPhase.oStore.sName, 'O2FeedMerge')
%                 disp([ '---- ' sType ' - EXME ' this.sUUID ]);
%                 disp(afFRs);
%                 disp([ 'Phase ' this.oPhase.sUUID ]);
%                 disp('>>>>>>>>');
%             else
%                 disp('XXXXXXXX');
%             end
            
            % Only merge or extract, depending on sType
            %TODO p2p should be separately, called in phase.update. p2p's
            %     update method should be called from solver when a phase
            %     in the system is updated. Merge phase has to be executed
            %     by solver as well, even if it is not connected to a
            %     solved branch, to make sure its always updated when P2P
            %     flowarte changes. P2ps do have to check the in- and
            %     outflows of phase to determine how much they absorb.
            for iI = 1:length(afFRs)
                if afFRs(iI) <= 0 && strcmp(sType, 'extract') && isa(this.aoFlows(iI), 'matter.procs.p2p')
                    this.extract(iI, afFRs(iI), fTimeStep);
                    
                elseif afFRs(iI) > 0 && strcmp(sType, 'merge') && ~isa(this.aoFlows(iI), 'matter.procs.p2p')
                    this.merge(iI, afFRs(iI), fTimeStep);
                    
                end
            end
            
            for iI = 1:length(afFRs)
                if afFRs(iI) < 0 && strcmp(sType, 'extract') && ~isa(this.aoFlows(iI), 'matter.procs.p2p')
                    this.extract(iI, afFRs(iI), fTimeStep);
                    
                elseif afFRs(iI) > 0 && strcmp(sType, 'merge') && isa(this.aoFlows(iI), 'matter.procs.p2p')
                    this.merge(iI, afFRs(iI), fTimeStep);
                    
                end
            end
            
            
            
%             if strcmp(this.oPhase.oStore.sName, 'O2FeedMerge')
%                 disp('<<<<<<<<');
%             end
        end
        
        function addFlow(this, oFlow)
            % For some more doc, see @matter.procs.f2f.addFlow()
            
            if this.oPhase.oStore.bSealed
                this.throw('addFlow', 'The store to which this processors phase belongs is sealed, so no ports can be added any more.');
            
            elseif ~isempty(this.aoFlows) && ~strcmp(this.sName, 'default')
                this.throw('addFlow', 'Only procs with the name ''default'' can handle several MFs ...');
            
            elseif ~isa(oFlow, 'matter.flow')
                this.throw('addFlow', 'The provided flow obj ~isa matter.flow!');
            
            elseif any(this.aoFlows == oFlow)
                this.throw('addFlow', 'The provided flow obj is already registered!');
            end
            
            iIdx               = length(this.aoFlows) + 1;
            this.aoFlows(iIdx) = oFlow;
            
            try
                [ iSign thFlow ] = oFlow.addProc(this, @() this.removeFlow(oFlow));
            catch oErr
                % Reset back to default MF
                this.aoFlows(iIdx) = this.oMT.oFlowZero;
                
                rethrow(oErr);
            end
            
            % Set the other stuff
            this.aiSign(iIdx)  = iSign;
            this.pthFlow(iIdx) = thFlow;
            
            
        end
        
        
        function arPartials = getPartials(this)
            % Get partial masses, CURRENT value, not stored, maybe outdated
            % one
            
            arPartials = this.oPhase.afMass ./ sum(this.oPhase.afMass);
        end
    end
    
    %% Extract / Merge methods
    methods (Access = protected)
        function extract(this, iFlow, fFlowRate, fTimeStep)
            % Flow rate should always be negative
            % Could get flow rate from flow itself, but would need to check
            % sign, so use the provided one
            
            % If a p2p proc, get arPartials for extraction from the proc
            % which might just selectively extract something!
            if isa(this.aoFlows(iFlow), 'matter.procs.p2p')
                %keyboard();
                %TODO see above, .update
                this.aoFlows(iFlow).update(fTimeStep);
                
                % Flowrate from flow after .update. Extract, so negative
                fFlowRate = -1 * abs(this.aoFlows(iFlow).fFlowRate);
                
                this.arPartials = this.aoFlows(iFlow).arPartialMass;
                
            else
                % arPartials might be outdated, so recalculate!
                %afExtractedMass = this.oPhase.arPartialMass * fFlowRate * fTimeStep;
                this.arPartials = this.oPhase.afMass ./ sum(this.oPhase.afMass);
            end
            
            % Absolute amount of extracted mass
            afExtractedMass = this.arPartials * fFlowRate * fTimeStep;
            
            % Too much mass requested?
            %TODO check for inf, nan etc, but if too large, just reduce
            %     accordingly?
            if any((this.oPhase.afMass + afExtractedMass) < 0)
                disp(this.oPhase.afMass + afExtractedMass);
                this.throw('extract', 'Asked exme %s to extract more mass then available in phase %s (store %s)', this.sName, this.oPhase.sName, this.oPhase.oStore.sName);
            end
            
            % Set the new mass within the phase object - protected
            % attribute so phase gave us a specific function handle, which
            % was written to this.setAttribute.
            this.setAttribute('afMass', this.oPhase.afMass + afExtractedMass);
        end
        
        function merge(this, iFlow, fFlowRate, fTimeStep)
            % Flow rate should always be positive
            %
            % Merge simply based on adding the thermal energies
            % See: http://de.wikipedia.org/wiki/Thermische_Energie
            %
            %TODO
            %   - include other stuff as well as kinetic energy?
            %     http://de.wikipedia.org/wiki/Innere_Energie
            %     -> see f2f/flows, need dynamic pressure etc
            %   - now, one calc for every MF at every port ... should maybe
            %     be done in one large calculation? So merge probably just
            %     returns values for thermal, kinetic, ... energy? Or do at
            %     least EXME-proc wide?
            %   - fTimeStep, here and in matter.container etc - also
            %     possible to just use some fixed, static time step in
            %     matter.table?
            
            % Just shortcuts for nicer equations below - temperatures and
            % masses of flow and phase
            fTemp_f = this.aoFlows(iFlow).fTemp;
            fM_f    = fFlowRate * fTimeStep;
            
            fTemp_p = this.oPhase.fTemp;
            fM_p    = this.oPhase.fMass;
            
            
            % mass * specific heat capacity - helper for next eq
            fMCP_f = fM_f * this.aoFlows(iFlow).fHeatCapacity;
            fMCP_p = fM_p * this.oPhase.fHeatCapacity;
            
            
            % Calculate new temperature. Just approximate, ideal approach
            % by using Q = m * c_p * T:
            % T = (m1 * c_p1 * T1 + m2 * c_p2 * T2) / (m1*c_p1 + m2*c_p2)
            %TODO as said above, optimize? Just return energies, also kin
            %     possible? At least EXME-Proc wide just ONE calculation!
            fTemp = (fMCP_f * fTemp_f + fMCP_p * fTemp_p) / (fMCP_f + fMCP_p);
            
            
            % Need to make sure that we get the current, updated partial
            % masses from the other EXME.
            arInputPartials = this.aoFlows(iFlow).oBranch.getPartials();
            
            % Calculate new mass vector in phase - just that, DO NOT update
            % the fMass etc! The flow just stores relative masses, so
            % multiply that vector with the actual flow rate.
            afMass = this.oPhase.afMass + fM_f * arInputPartials;%this.aoFlows(iFlow).arPartialMass;
            
            
            % Update JUST the temperature and partial mass vector - not the
            % mass, mol mass, heat capacity etc - done afterwards in phase 
            % update() method, so the other (subsequent) mergers are not
            % influenced and less computation time, probably ...
            this.setAttribute('fTemp',  fTemp);
            this.setAttribute('afMass', afMass);
            
            
            % If the connected flow is actually a p2p processor, call its
            % update method --> we changed our mass etc, so it needs to
            % recalculate flow rates etc
            %TODO put somewhere else, makes sense here? what if several p2p
            %     procs into this phase -> wait for ALL merges done and
            %     then call update on p2ps in this.update()?
            %   -> should be in something like the manual solver
%             if isa(this.aoFlows(iFlow), 'matter.procs.p2p')
%                 this.aoFlows(iFlow).update();
%             end
        end
        
    end
    
    
    %% Internal methdos for handling the flows/flow rates
    % The removeFlow is private - only accessible through anonymous handle
    methods (Access = private)
        function removeFlow(this, oFlow)
            iIdx = find(this.aoFlows == oFlow, 1);
            
            if isempty(iIdx), this.throw('removeFlow', 'Flow doesn''t exist'); end;
            
            %CHECK not required as in f2f to keep indices, right?
            this.aoFlows(iIdx) = [];%this.oMT.oFlowZero;
            this.aiSign(iIdx)  = [];
        end
    end
    
    % Protected methods - get flow rates, set matter properties
    methods (Access = protected)
        function afFRs = getFRs(this)
            if isempty(this.aoFlows), afFRs = [];
            else
                afFRs = [ this.aoFlows.fFlowRate ] .* this.aiSign;
            end
            
        end
        
        function set(this, iFlow, sFunc, varargin)
            % See matter.procs.f2f
            
            % Allow only setting if FR is negative, i.e. outflow!
            if this.aoFlows(iFlow).fFlowRate * this.aiSign(iFlow) < 0
                this.pthFlow(iFlow).(sFunc)(varargin{:});
            else
                this.throw('set', 'Can only set for negative flow rates (outflowing mass)');
            end
        end
    end
end

