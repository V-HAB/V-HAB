classdef exme < base
    %EXME extract/merge processor
    %   Extracts matter flow from and merges matter flow into a phase.
    %
    % See also matter.procs.f2f which has a lot in common.
    %
    %
    %TODO
    %   - for specific solvers, probably need additional methods. So either
    %     user needs to know solver and includes according EXME, or need
    %     some kind of proxy/decorator that the solver uses and places 'in
    %     front of' the actual EXME ...?
    %     Or similar to .setAttribute here, use function handles, maybe
    %     provided with some func handles from EXME/Flows/Branches/...?
    %   - exme/f2f same base class? also p2p?
    %   - instead of allowing several flows on 'default' port, introduce
    %     a bMultiple attribute?
    
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
        %arPartials;
        
        
        % TESTS - Pressures for merge
        %fPressureMerge   = 0;
        %fPressureExtract = 0;
    end
    
    
    
    methods
        function this = exme(oPhase, sName)
            %TODO at some point, remove this. At the same time, make the
            %     getPortProperties method here an ABSTRACT one!
            if ~isa(this, [ 'matter.procs.exmes.' oPhase.sType ])
                tStack = dbstack('-completenames');
                tStack = tStack(2);
                
                this.throw('exme', [ 'SORRY! Changed the EXME logic. This here should be a "matter.procs.exmes.' oPhase.sType '" instead of a "matter.proc.exme". ' sprintf('\n--------------------------------\n') 'TO FIX THIS go to file' sprintf('\n') '<a href="matlab:opentoline(' strrep(tStack.file, '\', '\\') ',' num2str(tStack.line) ')">' strrep(tStack.file, '\', '\\') ':' num2str(tStack.line) '</a> (CLICK ON THAT!)' sprintf('\n') 'and replace' sprintf('\n') '"matter.proc.exme("' sprintf('\n') 'with' sprintf('\n') '"matter.proc.exmes.' oPhase.sType '("' sprintf('\n--------------------------------\nExecute "help_checkEXMEs" to find all old exme calls!\n--------------------------------\n') ]);
            end
            
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
            
            %this.setAttribute = 
            oPhase.addProcEXME(this);
            
            this.oPhase = oPhase;
            
            
            
            % Create map for the func handles
            this.pthFlow = containers.Map('KeyType', 'single', 'ValueType', 'any');
        end
        
        
        function addFlow(this, oFlow)
            % For some more doc, see @matter.procs.f2f.addFlow()
            
            if this.oPhase.oStore.bSealed
                this.throw('addFlow', 'The store to which this processors phase belongs is sealed, so no ports can be added any more.');
            
            elseif ~isempty(this.aoFlows) && ~strcmp(this.sName, 'default')
                this.throw('addFlow', 'Only procs with the name ''default'' can handle several MFs ...');
            
            % Of p2p, only one flow can be connected, i.e. name cannot be
            % 'default' (which allows several flows)
            elseif isa(oFlow, 'matter.procs.p2ps.flow') && strcmp(this.sName, 'default')
                this.throw('addFlow', 'A p2p flow processor can''t be added to the ''default'' port!');
            
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
        
        
        
        function [ afFlowRates, mrPartials, mfProperties ] = getFlowData(this)
            % Return all flow rates, plus the according partial mass
            % ratios. Depends on flow direction and flow type: if a p2p
            % flow processor is connected, getting the arPartials from
            % there either way. Else, if outflowing, return phase partials,
            % and if inflowing, again get from flow.
            %
            % Also returns matrix with two columns containing temperature 
            % and the heat capacity and for each flow!
            
            afFlowRates  = this.getFRs()';
            mrPartials   = zeros(length(afFlowRates), length(this.oPhase.arPartialMass));
            mfProperties = zeros(length(afFlowRates), 2);
            
            %TODO store that on attribute as bP2P = true or something?
            if isa(this.aoFlows(1), 'matter.procs.p2ps.flow')
                % Can only be one flow, if p2p!
                %mrPartials = repmat(this.aoFlows(1).arPartials, length(afFlowRates), 1);
                mrPartials   = this.aoFlows(1).arPartialMass;
                mfProperties = [ this.aoFlows(1).fTemp this.aoFlows(1).fHeatCapacity ];
            else
                %TODO cache length!
                for iF = 1:length(afFlowRates)
                    if afFlowRates(iF) > 0 % merge
                        %CHECK do we need to get that from other side, in
                        %      case that changed? Shouldn't need that, when
                        %      mass is extracted on the other side, the
                        %      arPartialMass from that phase is used - but
                        %      if that get's updated, fr recalc is called 
                        %      on all branches which would set the new
                        %      arPartials on all flows ... right?
                        mrPartials(iF, :)   = this.aoFlows(iF).arPartialMass;
                        mfProperties(iF, :) = [ this.aoFlows(iF).fTemp this.aoFlows(iF).fHeatCapacity ];
                        
                    else % extract or zero - phase partials
                        %NOTE possibility to implement special EXME that
                        %     provides an adjusted partial masses vector.
                        %     For example a filter with an inflow at one
                        %     end, and then throughout the axial dimension,
                        %     some additional outflow ports. EXMEs would be
                        %     linked to the filter model and know their
                        %     position -> could ask the filter model for
                        %     the partial pressure of the filtered species
                        %     at that position and adjust the partial mass
                        %     here accordingly.
                        mrPartials(iF, :)   = this.oPhase.arPartialMass;
                        mfProperties(iF, :) = [ this.oPhase.fTemp this.oPhase.fHeatCapacity ];
                    end
                end
            end
        end
        
        % Method returns absolute values of pressure and temperature of the
        % extracted matter
        % For e.g. a liquid phase, the pressure would depend on gravity,
        % filling level and position of the port, which could be
        % implemented by a derived version of the EXME. See the according
        % matter.procs.exme.[phase type] for that.
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            this.throw('getPortProperties', 'Can''t be called in matter.procs.exme');
        end
        
        
        function [ arPartialMass, fMolMass, fHeatCapacity ] = getMatterProperties(this)
            %CHECK If a p2p processor asks for the port properties, makes
            %      sense to return the phase partials. The p2p itself can
            %      set another arPartialMass, for extracting selectively,
            %      so if one needs to get the flow partials, the p2p has to
            %      be asked (or aoFlows(iI).oBranch which references back
            %      to the p2p). Does that make sense?
            arPartialMass = this.oPhase.arPartialMass;
            
            fMolMass      = this.oPhase.fMolMass;
            fHeatCapacity = this.oPhase.fHeatCapacity;
        end
    end
    
    %% ABSTRACT METHODS - the concrete exmes have to define those!
    methods (Abstract = true)
        
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

