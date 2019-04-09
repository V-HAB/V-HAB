classdef flow < matter.procs.p2p
    %FLOW A P2P processor for flow phases, this processor must be used if a
    % p2p is used in a flow node
    
    properties (SetAccess = protected, GetAccess = protected)
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    
    
    methods
        function this = flow(varargin)
            this@matter.procs.p2p(varargin{:});
            
            if ~this.oIn.oPhase.bFlow && ~this.oOut.oPhase.bFlow
                % P2Ps of this type are intended to be used in conjunction
                % with flow phases which have no mass. If you want to use a
                % P2P in a normal phase please use the stationary P2P type!
                this.throw('p2p', 'The flow P2P %s does not have a flow phase as either input or output. One side of the P2P must be a flow phase! For normal phases use stationary P2Ps!', this.sName);
            end
            
        end
    end
    
    methods (Abstract)
        % This function is called by the multibranch solver, which also
        % calculates the inflowrates and partials (as the p2p flowrates
        % themselves should not be used for that we cannot use the gas
        % flow node values directly otherwise the P2P influences itself)
        % 
        % afInFlowRates: vector containin the total mass flowrates entering
        %                the flow phase
        % aarInPartials: matrix containing the corresponding partial mass
        %                ratios of the inflowrates
        %
        % You can use afPartialInFlows = sum((afInFlowRates .* aarInPartials),1);
        % to calculate the total partial inflows in kg/s
        calculateFlowRate(this, afInsideInFlowRate, aarInsideInPartials, afOutsideInFlowRate, aarOutsideInPartials)
        % The Inside is considered to be the phase attached to the oIn exme
        % of this P2P, while the outside is considered to be the phase
        % attached to the oOut exme of this p2p.
        
    end
    
    %% Internal helper methods
    methods (Access = protected)
        function setMatterProperties(this, fFlowRate, arPartials)
            % If p2p is updated, needs to set new flow rate through this 
            % method, and also new partials. 
            this.fLastUpdate = this.oStore.oTimer.fTime;
            
            % The phase that called update already did matterupdate, but 
            % set the fLastUpd to curr time so doesn't do that again
            this.oIn.oPhase.registerMassupdate();
            this.oOut.oPhase.registerMassupdate();
            
            
            % Set matter properties. Calculates molar mass, heat capacity,
            % etc.
            setMatterProperties@matter.procs.p2p(this, fFlowRate, arPartials);
            
        end
    end
end

