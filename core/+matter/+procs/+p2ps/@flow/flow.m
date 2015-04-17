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
        function [ afInFlowrates, mrInPartials ] = getInFlows(this, sPhase)
            % Return vector with all INWARD flow rates and matrix with 
            % partial masses of each in flow
            %
            %TODO also check for matter.manips.substances, and take the change
            %     due to that also into account ... just as another flow
            %     rate? Should the phase do that?
            
            if nargin < 2, sPhase = 'in'; end;
            
            oPhase = sif(strcmp(sPhase, 'in'), this.oIn.oPhase, this.oOut.oPhase);
            
            %CHECK store on obj var, as long as the amount of inflows
            %      doesn't change -> kind of preallocated?
            mrInPartials  = zeros(0, this.oMT.iSubstances);
            afInFlowrates = [];
            
            % See phase.getTotalMassChange
            for iI = 1:oPhase.iProcsEXME
                [ afFlowRates, mrFlowPartials, mfProperties ] = oPhase.coProcsEXME{iI}.getFlowData();
                
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    mrInPartials  = [ mrInPartials;  mrFlowPartials(abInf, :) ];
                    afInFlowrates = [ afInFlowrates; afFlowRates(abInf) ];
                end
            end
            
            
            % Add inner mass - mass, but assume timestep of 1s for process.
            %mrInPartials  = [ mrInPartials;  oPhase.arPartialMass ];
            %afInFlowrates = [ afInFlowrates; oPhase.fMass / 1 ];
            
            
            % Check manipulator for partial
            if ~isempty(oPhase.toManips.substances) && ~isempty(oPhase.toManips.substances.afPartial)
                % Was updated just this tick - partial changes in kg/s
                % Only get positive values, i.e. produced species
                afTmpPartials    = oPhase.toManips.substances.afPartial;
                aiTmpPartialsPos = afTmpPartials > 0;
                afManipPartials  = zeros(1, length(afTmpPartials));
                
                afManipPartials(aiTmpPartialsPos) = afTmpPartials(aiTmpPartialsPos);
                %afManipPartials = oPhase.toManips.substances.afPartial(oPhase.toManips.substances.afPartial > 0);
                fManipFlowRate  = sum(afManipPartials);
                %keyboard();
                
                if fManipFlowRate > 0
                    mrInPartials  = [ mrInPartials;  afManipPartials / fManipFlowRate ];
                    afInFlowrates = [ afInFlowrates; fManipFlowRate ];
                end
            end
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

