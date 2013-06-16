classdef flow < matter.procs.p2p
    %P2P
    %
    %TODO
    %   - getInFlows, or overall logic for amount / type of EXMEs etc
    %   - if no arPartials provided - instead of the one from the phase,
    %     just use the old one?
    
    
    properties (SetAccess = protected, GetAccess = protected)
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    
    
    methods
        function this = flow(varargin)
            this@matter.procs.p2p(varargin{:});
            
        end
    end
    
    
    
    %% Internal helper methods
    methods (Access = protected)
        function [ afFlowRates, mrPartials ] = getInFlows(this)
            % Return vector with all INWARD flow rates and matrix with 
            % partial masses of each in flow
            
            %TODO-NOW
        end
        
        
        
        function setMatterProperties(this, fFlowRate, arPartials)
            % Overwrites the basic setData, does some other stuff. If p2p
            % is updated, needs to set new flow rate through this method,
            % and also new partials.
            %TODO possible to also change the temperature? Just set fTemp,
            %     not used by oIn (if fFR > 0) anyway.
            
            this.fLastUpdate = this.oStore.oTimer.fTime;
            
            % The phase that called update already did matterupdate, but 
            % set the fLastUpd to curr time so doesn't do that again
            this.oIn.oPhase.massupdate();
            this.oOut.oPhase.massupdate();
            
            
            % Set matter properties. Calculates mol mass, heat capacity etc
            setMatterProperties@matter.procs.p2p(this, fFlowRate, arPartials);
            
        end
    end
end

