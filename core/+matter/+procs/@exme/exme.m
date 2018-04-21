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
        % @type object
        oPhase;
        
        % Matter table
        % @type object
        oMT;
        
        % Timer
        % @type object
        oTimer;
        
        % Name of processor. If 'default', several MFs can be connected
        %TODO make that configurable?
        % @type string
        sName;
        
        % Connected matter flow
        oFlow = matter.flow.empty();
        
        % HAs a flow?
        bHasFlow = false;
        
        % Is flow a p2p?
        bFlowIsAProcP2P = false;
        
        
        % See @matter.procs.f2f
        iSign;

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
            this.oMT    = oPhase.oMT;
            this.oTimer = oPhase.oTimer;
            
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
            
            elseif ~isempty(this.oFlow)
                this.throw('addFlow', 'There is already a flow connected to this exme! You have to create another one.');
            
            elseif ~isa(oFlow, 'matter.flow')
                this.throw('addFlow', 'The provided flow object is not a matter.flow!');
            
            elseif any(this.oFlow == oFlow)
                this.throw('addFlow', 'The provided flow object is already registered!');
            end
            
            this.oFlow = oFlow;
            
            
            
            this.bHasFlow = true;
            this.bFlowIsAProcP2P = isa(this.oFlow, 'matter.procs.p2ps.flow') || isa(this.oFlow, 'matter.procs.p2ps.stationary');
            
            
            try
                [ this.iSign, this.pthFlow ] = oFlow.addProc(this, @() this.removeFlow(oFlow));
            catch oErr
                % Reset back to default MF
                this.oFlow = this.oMT.oFlowZero;
                
                rethrow(oErr);
            end
            
        end
        
        
        
        function [ fFlowRate, arPartials, afProperties ] = getFlowData(this, fFlowRate)
            % Return the flow rate, plus the according partial mass
            % ratios. Depends on flow direction and flow type: if a p2p
            % flow processor is connected, getting the arPartials from
            % there either way. Else, if outflowing, return phase partials,
            % and if inflowing, again get from flow.
            %
            % Also returns matrix with two columns containing temperature 
            % and the heat capacity and for each flow!
            
            % If there is no flow connected to this exme yet, it returns
            % placeholder values.
            %CHECK is this even executed, or is there an earlier warning of
            % 'unused exme'? In that case, this condition can be deleted.
            if ~this.bHasFlow
                fFlowRate    = 0;
                arPartials   = [];
                afProperties = [];
                
                return;
            end
            
            % The flow rate property of the flow is unsigned, so we have to
            % add it again by multiplying with the iSign property of this
            % exme. 
            if nargin >= 2 && ~isempty(fFlowRate)
                fFlowRate  =  fFlowRate * this.iSign;
            else
                fFlowRate  =  this.oFlow.fFlowRate * this.iSign;
            end
            
            
            if this.bFlowIsAProcP2P
                % This exme is connected to a P2P processor, so we can get
                % the properties from the connected flow.
                arPartials   = this.oFlow.arPartialMass;
                afProperties = [ this.oFlow.fTemperature this.oFlow.fSpecificHeatCapacity ];
            else
                
                if fFlowRate > 0 
                    % The flow rate is larger than zero, this means we use
                    % the properties of the incoming flow.
                    %CHECK do we need to get that from other side, in
                    %      case that changed? Shouldn't need that, when
                    %      mass is extracted on the other side, the
                    %      arPartialMass from that phase is used - but
                    %      if that get's updated, fr recalc is called
                    %      on all branches which would set the new
                    %      arPartials on all flows ... right?
                    arPartials   = this.oFlow.arPartialMass;
                    afProperties = [ this.oFlow.fTemperature this.oFlow.fSpecificHeatCapacity ];
                    
%                     if this.oFlow.oBranch.coExmes{2} == this
%                         arPartials   = this.oFlow.oBranch.coExmes{1}.getMatterProperties(); %oPhase.arPartialMass;
%                     else
%                         arPartials   = this.oFlow.oBranch.coExmes{2}.getMatterProperties(); %oPhase.arPartialMass;
%                     end
                    
                else 
                    % The flow rate is either zero or negative, which means
                    % matter is flowing out of the phase. In both cases we
                    % have to use the matter properties of the connected
                    % phase.
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
                    %
                    %EXPERIMENTAL flow phase - partials is NOT based on
                    % phase contents, but inflows! Calculated in the
                    % previous step, so use branches value!
                    %TODO instead of FR == 0 check, should we check if the
                    %  flow rate * the last step is roughly in the area of
                    %  the stored mass?
                    arPartials   = sif(~this.oPhase.bFlow || this.oFlow.fFlowRate == 0, this.oPhase.arPartialMass, this.oFlow.arPartialMass);
                    afProperties = [ this.oPhase.fTemperature this.oPhase.oCapacity.fSpecificHeatCapacity ];
                end
            end
        end

        
        % Method returns absolute values of pressure and temperature of the
        % extracted matter
        % For e.g. a liquid phase, the pressure would depend on gravity,
        % filling level and position of the port, which could be
        % implemented by a derived version of the EXME. See the according
        % matter.procs.exme.[phase type] for that.
        %TODO make this an abstract method?
        function [ fPortPressure, fPortTemperature ] = getPortProperties(this)
            this.throw('getPortProperties', 'Can''t be called in matter.procs.exme');
            
            % These two lines are only here to make MATLAB shut up about
            % unset return variables.
            fPortPressure = 0;
            fPortTemperature = 0;
        end
        
        
        function [ arPartialMass, fMolarMass, fSpecificHeatCapacity ] = getMatterProperties(this)
            %CHECK If a p2p processor asks for the port properties, makes
            %      sense to return the phase partials. The p2p itself can
            %      set another arPartialMass, for extracting selectively,
            %      so if one needs to get the flow partials, the p2p has to
            %      be asked (or aoFlows(iI).oBranch which references back
            %      to the p2p). Does that make sense?
            arPartialMass = this.oPhase.arPartialMass;
            
            fMolarMass            = this.oPhase.fMolarMass;
            fSpecificHeatCapacity = this.oPhase.oCapacity.fSpecificHeatCapacity;
            
            
            % Return INFLOW matter properties, not the matter properties of
            % the actual phase. This means "real" inflows, then all in- and
            % outflowing p2ps, and the possible manip.
            %TODO for now, as an intermediate step, using bFlow instead of
            %     bSynced. At some point, this code will probably be moved
            %     to a gas_flow_phase or similar.
            if this.oPhase.bFlow
                %NOTE these should probably be named e.g. afRelevantFlows
                %     because e.g. p2ps both in and out used!
                mrInPartials  = zeros(this.oPhase.iProcsEXME, this.oMT.iSubstances);
                afInFlowrates = zeros(this.oPhase.iProcsEXME, 1);
                
                % Creating an array to log which of the flows are not in-flows
                % This will include only real matter, no p2ps - they will
                % all be included, no matter the direction.
                aiOutFlows = ones(this.oPhase.iProcsEXME, 1);
                
                
                % Need to make sure a flow rate exists. Because p2ps depend
                % on the normal branch inflows (at least outflowing p2ps),
                % don't include those in the check for an existing flow
                % rate - only return the 'inflow' based partials if there
                % is actually a real flow rate.
                fInwardsFlowRates = 0;
                
                % Get flow rates and partials from EXMEs
                for iI = 1:this.oPhase.iProcsEXME
                    [ fFlowRate, arFlowPartials, ~ ] = this.oPhase.coProcsEXME{iI}.getFlowData();
                    
                    % Include if EITHER an (real) inflow, OR a p2p (but not
                    % ourselves!) in either direction (p2ps can change
                    % matter composition, therefore include both in and
                    % outflowing)
                    if fFlowRate > 0 || (this.oPhase.coProcsEXME{iI} ~= this && this.oPhase.coProcsEXME{iI}.bFlowIsAProcP2P)
                        mrInPartials(iI,:) = arFlowPartials;
                        afInFlowrates(iI)  = fFlowRate;
                        aiOutFlows(iI)     = 0;
                        
                        %if ~this.oPhase.coProcsEXME{iI}.bFlowIsAProcP2P
                        if fFlowRate > 0
                            fInwardsFlowRates = fInwardsFlowRates + fFlowRate;
                        end
                    end
                end

                % Now we delete all of the rows in the mfInflowDetails matrix
                % that belong to out-flows.
                if any(aiOutFlows)
                    mrInPartials(logical(aiOutFlows),:)  = [];
                    afInFlowrates(logical(aiOutFlows),:) = [];
                end

                
                for iF = 1:length(afInFlowrates)
                    mrInPartials(iF, :) = mrInPartials(iF, :) .* afInFlowrates(iF);
                end
                
                % Include possible manipulator, which uses an array of
                % absolute flow-rates for the different substances
                % Also depends on normal inflow branches, so do not include
                % with the fInwardsFlowRates check.
                if ~isempty(this.oPhase.toManips.substance) && ~isempty(this.oPhase.toManips.substance.afPartialFlows)
                    % The sum() of the flow rates of a substance manip
                    % should always be zero. Therefore, split positive and
                    % negative rates and see as two flows.
                    afManipPartialsIn  = this.oPhase.toManips.substance.afPartialFlows;
                    afManipPartialsOut = this.oPhase.toManips.substance.afPartialFlows;
                    
                    afManipPartialsIn (afManipPartialsIn  < 0) = 0;
                    afManipPartialsOut(afManipPartialsOut > 0) = 0;
                    
                    
                    afInFlowrates(end + 1) = sum(afManipPartialsIn);
                    afInFlowrates(end + 1) = sum(afManipPartialsOut);
                    
                    mrInPartials(end + 1, :) = afManipPartialsIn;
                    mrInPartials(end + 1, :) = afManipPartialsOut;
                end
                
                
                fTotalInFlowRate = sum(afInFlowrates);
                afTotalSubstanceInflows = sum(mrInPartials, 1); %note we did multiply mrInPartials with flow rates above, so actually total partial flows!
                
                
                % Only use the inflow partial masses if there is actually
                % an inflow of mass.
                if fInwardsFlowRates ~= 0
                    %NOTE we should probably move this whole thing to a
                    %     flow phase class, which then regularly updates
                    %     the heat capa automatically but contains
                    
                    % if the p2p removed more mass flow than is entering
                    % the flow node, negative partial mass values can be
                    % generated. Should we simply set the value to 0 in
                    % that case? It would allow the p2p to generate mass.
                    % Otherwise is it possible to set the p2p flowrate to a
                    % value that prevents negative masses from occuring
                    % (maximum value for partial p2p flowrate is equal to
                    % inflow rate)?
                    arPartialMass = afTotalSubstanceInflows ./ fTotalInFlowRate;
                    arPartialMass(arPartialMass < 0) = 0;
                    fMolarMass    = this.oMT.calculateMolarMass(afTotalSubstanceInflows);
                end
                
                
                %afFlowRate = afFlowRate .* mrPartials(:, iSpecies);
            end
        end
    end
    
    %% ABSTRACT METHODS - the concrete exmes have to define those!
    methods (Abstract = true)
        
    end
    
    
    %% Internal methdos for handling the flows/flow rates
    % The removeFlow is private - only accessible through anonymous handle
    methods (Access = private)
        function removeFlow(this, ~ )
            % Here we need the tilde as an input parameter, because the
            % removeFlow method for the matter table and the f2f processor
            % need to specify which flow is to be removed. Since exmes only
            % have one input parameter, this is not necessary here. 
            this.oFlow = matter.flow.empty();
            this.iSign = 0;
        end
    end
    
    % Protected methods - get flow rates, set matter properties
    methods (Access = protected)
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

