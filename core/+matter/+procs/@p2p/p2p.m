classdef p2p < matter.flow
    %P2P
    %
    %TODO
    %   - 
    
    
    properties (SetAccess = protected, GetAccess = private)
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        sName;
        oStore;
    end
    
    
    
    methods
        function this = p2p(oStore, sName, sPhaseIn, sPhaseOut)
            % p2p constructor.
            %
            % Parameters:
            %   - sName         Name of the processor
            
            % Parent constructor
            this@matter.flow(oStore.oMT);
            
            % Find the phases
            iPhaseIn  = find(strcmp({ oStore.aoPhases.sName }, sPhaseIn ), 1);
            iPhaseOut = find(strcmp({ oStore.aoPhases.sName }, sPhaseOut), 1);
            
            if isempty(iPhaseIn) || isempty(iPhaseOut)
                this.throw('p2p', 'Phase could not be found: in phase %s has index %i, %s has index %i', sPhaseIn, iPhaseIn, sPhaseOut, iPhaseOut);
            end
            
            % Set name and a fake oBranch ref - back to ourself
            this.sName   = sName;
            this.oBranch = this;
            this.oStore  = oStore;
            
            % Can only be done after this.oStore is set, store checks that!
            this.oStore.addP2P(this);
            
            this.fFlowRate = 0;
            
            % Add ourselves to phase ports (default name!)
            %TODO do the phases need some .getPort or stuff?
            oStore.aoPhases(iPhaseIn ).toProcsEXME.default.addFlow(this);
            oStore.aoPhases(iPhaseOut).toProcsEXME.default.addFlow(this);
        end
    end
    
    
    
    %% Methods required for the matter handling
    methods
        function exec(this, fTime)
            % Called from subsystem to update the internal state of the
            % processor, e.g. change efficiencies etc
        end
        
        function update(this, fTimeStep)
            % Calculate new flow rate in [kg/s]. The update method is
            % called right before the phases merge/extract. The p2p merge
            % or extract is done after the merge of the 'outer' flows and
            % before the extract of those takes places.
            % Therefore, at the point of p2p extraction, the whole (tempo-
            % rary) mass flowing through the phase within that time step is
            % stored in the phase.
            % An absolute value for mass extraction has to be divided by
            % the fTimeStep parameter to get a flow.
            
            %this.oOut.oPhase.update(fTimeStep);
        end
        
        
        function arPartials = getPartials(this)
            % Fake - we provide 'this' as oBranch --> the EXME.merge calls
            % .getPartials on aoFlows(iFlow).oBranch but get's this method
            % here
            
            arPartials = this.arPartialMass;
        end
    end
    
end

