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
        
        
        % TESTS - Pressures for merge
        fPressureMerge   = 0;
        fPressureExtract = 0;
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
            
            % TESTS
%             if strcmp(sType, 'merge')
%                 %this.fPressureMerge = sum(this.oPhase.afMass) * this.oPhase.calculatePressureCoefficient();
%                 %this.fPressureExtract = sum(this.oPhase.afMass) * this.oPhase.calculatePressureCoefficient();
%             end
            
            
            afFRs = this.getFRs();
            
            
            %  Extract p2ps or merge flows
            %TODO has to be in phase, several EXMEs can exist with p2ps!
            for iI = 1:length(afFRs)
                if afFRs(iI) < 0 && strcmp(sType, 'extract') && isa(this.aoFlows(iI), 'matter.procs.p2p')
                    this.extract(iI, afFRs(iI), fTimeStep);
                    
                elseif afFRs(iI) > 0 && strcmp(sType, 'merge') && ~isa(this.aoFlows(iI), 'matter.procs.p2p')
                    this.merge(iI, afFRs(iI), fTimeStep);
                    
                end
            end
            
            

            % TESTS -- SEE BELOW!
            % POST NORMAL mergers and PRE P2P mergers - cache pressure
%             if strcmp(sType, 'merge')
%                 %TEST - update p2p's here?
% %                 for iI = 1:length(afFRs)
% %                     if isa(this.aoFlows(iI), 'matter.procs.p2p')
% %                         this.aoFlows(iI).update(fTimeStep);
% %                     end
% %                 end
% %                 
% %                 afFRs = this.getFRs();
%                 
%                 this.fPressureMerge = sum(this.oPhase.afMass) * this.oPhase.calculatePressureCoefficient();
%                 
%             % POST P2P extractors and PRE NORMAL extractor
%             else
%                 this.fPressureExtract = sum(this.oPhase.afMass) * this.oPhase.calculatePressureCoefficient();
%             end
            
            
            % Now the extract flows or merge p2ps
            for iI = 1:length(afFRs)
                if afFRs(iI) < 0 && strcmp(sType, 'extract') && ~isa(this.aoFlows(iI), 'matter.procs.p2p')
                    this.extract(iI, afFRs(iI), fTimeStep);
                    
                elseif afFRs(iI) > 0 && strcmp(sType, 'merge') && isa(this.aoFlows(iI), 'matter.procs.p2p')
                    this.merge(iI, afFRs(iI), fTimeStep);
                    
                end
            end
            


            % TESTS - due to p2p, theoretically different pressures at in
            % and outflowing ports. However, ignore - generally just small
            % amounts (e.g. CO2) extracted. If large percentages are
            % extracted, possibly use three phases - in phase, absorbed,
            % and out phase - 2nd p2p proc after in -> absorb p2p.
            % Also, this would have to be done 'outside' the EXME, in the
            % phase, as several EXMEs can exist.
%             if strcmp(sType, 'extract')
%                 %this.fPressureExtract = sum(this.oPhase.afMass) * this.oPhase.calculatePressureCoefficient();
%                 %this.fPressureMerge = sum(this.oPhase.afMass) * this.oPhase.calculatePressureCoefficient();
%                 
%                 fTmpPress =  sum(this.oPhase.afMass) * this.oPhase.calculatePressureCoefficient();
%                 
%                 if fTmpPress == 0
%                     this.fPressureExtract = 0;
%                     this.fPressureMerge   = 0;
%                 else
%                     this.fPressureExtract = fTmpPress * this.fPressureExtract / this.fPressureMerge;
%                     this.fPressureMerge   = fTmpPress;
%                 end
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
        
        
        
        
        
        %% SOLVER STUFF
        %TODO the solver methods shouldn't be directly in matter.procs.exme
        %     and matter.flow, or changed to a more general functionality!
        
        % Method returns absolute values of pressure and temperature of the
        % extracted matter
        % For e.g. a liquid phase, the pressure would depend on gravity,
        % filling level and position of the port, which could be
        % implemented by a derived version of the EXME.
        %TODO depending on phase type, different EXME implementations.
        %     Solids do not have a pressure, liquids no fPressure, ...
        function [ fPortPressure fPortTemperature ] = solverExtract(this, fFlowRate)
            %fPortPressure    = this.fPressureExtract;
            fPortPressure    = this.oPhase.fPressure;
            fPortTemperature = this.oPhase.fTemp;
        end
        
        % See above - liquid phase might not have fPressure, but a pressure
        % needs to be calculated depending on the port position.
        function fPortPressure = solverMerge(this, fFlowRate)
            
            fPortPressure = this.oPhase.fPressure;
            %fPortPressure = this.fPressureMerge;
        end
        
        
        function [ arPartialMass, fMolMass, fHeatCapacity ] = getMatterProperties(this)
            %TODO Don't use arPartialmass, recalc - might not be updated?
            arPartialMass = this.oPhase.arPartialMass;
            %arPartialMass = this.oPhase.afMass ./ sum(this.oPhase.afMass);
            
            fMolMass      = this.oPhase.fMolMass;
            fHeatCapacity = this.oPhase.fHeatCapacity;
        end
        
        %%%%%%%% SOLVER END %%%%%%%%
    end
    
    %% Extract / Merge methods
    methods (Access = protected)
        function extract(this, iFlow, fFlowRate, fTimeStep)
            % Flow rate should always be negative
            % Could get flow rate from flow itself, but would need to check
            % sign, so use the provided one
            
            % If a p2p proc, get arPartials for extraction from the proc
            % which might just selectively extract something!
            %TODO don't store this.arPartials, also for second case, use
            %     the stored arPartials on phase -> after extract p2p,
            %     arPartials have to be recalculated in phase
            if isa(this.aoFlows(iFlow), 'matter.procs.p2p')
                this.arPartials = this.aoFlows(iFlow).arPartialMass;
                
            else
                % arPartials might be outdated, so recalculate!
                %afExtractedMass = this.oPhase.arPartialMass * fFlowRate * fTimeStep;
                this.arPartials = this.oPhase.afMass ./ sum(this.oPhase.afMass);
            end
            
            % Absolute amount of extracted mass
            afExtractedMass = this.arPartials * fFlowRate * fTimeStep;
            
            % Too much mass requested?
            if any(tools.round.prec(this.oPhase.afMass + afExtractedMass) < 0)
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

