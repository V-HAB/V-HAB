classdef flow < matter.procs.p2p
    %FLOW A P2P processor for a phase where the volumetric flow through the
    %phase is significantly larger than its volume. 
    %
    %TODO
    %   - getInFlows, or overall logic for amount / type of EXMEs etc
    %   - if no arPartials provided - instead of the one from the phase,
    %     just use the old one?
    %   - getInFlows - ONLY for 'in' phase? Definition that p2p can ONLY
    %     depend on the inflow properties of the oIn phase??
    
    
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
        function [ afInFlowrates, mrInPartials ] = getInFlows(this, sPhase)
            % Return vector with all INWARD flow rates and matrix with 
            % partial masses of each in flow
            %
            %TODO also check for matter.manips.substances, and take the change
            %     due to that also into account ... just as another flow
            %     rate? Should the phase do that?
            
            if nargin < 2, sPhase = 'in'; end
            
            oPhase = sif(strcmp(sPhase, 'in'), this.oIn.oPhase, this.oOut.oPhase);
            
            % Initializing temporary matrix and array to save the per-exme
            % data. 
            mrInPartials  = zeros(oPhase.iProcsEXME, this.oMT.iSubstances);
            afInFlowrates = zeros(oPhase.iProcsEXME, 1);
            
            % Creating an array to log which of the flows are not in-flows
            abOutFlows = true(oPhase.iProcsEXME, 1);
            
            % Get flow rates and partials from EXMEs
            for iI = 1:oPhase.iProcsEXME
                [ afFlowRates, mrFlowPartials, ~ ] = oPhase.coProcsEXME{iI}.getFlowData();
                
                % The afFlowRates is a row vector containing the flow rate
                % at each flow, negative being an extraction!
                % mrFlowPartials is matrix, each row has partial ratios for
                % a flow, cols are the different substances.
                
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    mrInPartials(iI,:) = mrFlowPartials(abInf, :);
                    afInFlowrates(iI)  = afFlowRates(abInf);
                    abOutFlows(iI)     = false;
                end
            end
            
            % Now we delete all of the rows in the mrInPartials matrix
            % that belong to out-flows.
            if any(abOutFlows)
                mrInPartials(abOutFlows,:)  = [];
                afInFlowrates(abOutFlows,:) = [];
            end
            
            % Check manipulator for partial
            if ~isempty(oPhase.toManips.substance) && ~isempty(oPhase.toManips.substance.afPartialFlows)
                this.warn('getInFlows', 'Unsafe when using a manipulator. Use getPartialInFlows instead!');
            end
        end
        
        
        function aafPartials = getPartialInFlows(this, sPhase)
            % Return matrix with all INWARD flow rates and matrix with 
            % partial masses of each in flow in kg/s per flow / substance
            % To get the total flow rate of each substance into the phase:
            % 
            % afPartialFlows = afFlowRate .* mrPartials(:, iSpecies)
            %
            %TODO clean up - from getFlowData, afFlowRates is afFlowRate
            %     and mrFLowPartails is actually arFlowPartials!
            %     -> simplify!
            
            if nargin < 2, sPhase = 'in'; end
            
            oPhase = sif(strcmp(sPhase, 'in'), this.oIn.oPhase, this.oOut.oPhase);
            
            % Initializing temporary matrix and array to save the per-exme
            % data. 
            aafPartials  = zeros(oPhase.iProcsEXME, this.oMT.iSubstances);
            
            % Creating an array to log which of the flows are not in-flows
            aiOutFlows = ones(oPhase.iProcsEXME, 1);
            
            % Get flow rates and partials from EXMEs
            for iI = 1:oPhase.iProcsEXME
                [ fFlowRate, arFlowPartials, ~ ] = oPhase.coProcsEXME{iI}.getFlowData();
                
                % The afFlowRates is a row vector containing the flow rate
                % at each flow, negative being an extraction!
                % mrFlowPartials is matrix, each row has partial ratios for
                % a flow, cols are the different substances.
                
                bInf = (fFlowRate > 0);
                
                if bInf
                    aafPartials(iI,:) = fFlowRate .* arFlowPartials;
                    aiOutFlows(iI)    = 0;
                end
            end
            
            % Now we delete all of the rows in the aafPartials matrix
            % that belong to out-flows.
            if any(aiOutFlows)
                aafPartials(logical(aiOutFlows),:)  = [];
            end
            
            % Check manipulator for partial
            if ~isempty(oPhase.toManips.substance) && ~isempty(oPhase.toManips.substance.afPartialFlows)
                % Was updated just this tick - partial changes in kg/s
                afTmpPartials = oPhase.toManips.substance.afPartialFlows;
                
                if any(afTmpPartials)
                    aafPartials  = [ aafPartials;  afTmpPartials ];
                end
            end
        end
        
        
        
        function setMatterProperties(this, fFlowRate, arPartials)
            % If p2p is updated, needs to set new flow rate through this 
            % method, and also new partials.
            %TODO possible to also change the temperature? Just set fTemperature,
            %     not used by oIn (if fFR > 0) anyway.
            
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

