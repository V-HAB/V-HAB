classdef p2p < matter.flow
    %P2P
    %
    %TODO
    %   - 
    
    
    properties (SetAccess = private, GetAccess = private)
        
    end
    
    properties (SetAccess = protected, GetAccess = public)
        sName;
    end
    
    
    
    methods
        function this = p2p(oMT, sName, oPhaseIn, oPhaseOut)
            % p2p constructor.
            %
            % Parameters:
            %   - sName         Name of the processor
            
            % Parent constructor
            this@matter.flow(oMT);
            
            % Set name and a fake oBranch ref - back to ourself
            this.sName   = sName;
            this.oBranch = this;
            
            this.fFlowRate = 0;
            
            % Add ourselves to phase ports (default name!)
            %TODO do the phases need some .getPort or stuff?
            oPhaseIn.toProcsEXME.default.addFlow(this);
            oPhaseOut.toProcsEXME.default.addFlow(this);
        end
    end
    
    
    
    %% Methods required for the matter handling
    methods
        function exec(this, fTime)
            % Called from subsystem to update the internal state of the
            % processor, e.g. change efficiencies etc
        end
        
        function update(this, fTimeStep)
            % Called by phase when merging stuff to update flow rates etc
            
            this.oOut.oPhase.update(fTimeStep);
        end
        
        
        function arPartials = getPartials(this)
            % Fake - we provide 'this' as oBranch --> the EXME.merge calls
            % .getPartials on aoFlows(iFlow).oBranch but get's this method
            % here
            
            arPartials = this.arPartialMass;
        end
    end
    
end

