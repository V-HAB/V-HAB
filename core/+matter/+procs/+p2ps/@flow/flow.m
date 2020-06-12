classdef flow < matter.procs.p2p
    %FLOW A P2P processor for flow phases where the P2P flow rate depends
    % on the flowrate passing thorugh the phases to which the P2P is
    % connected. The flowrate of the P2P is solver iterativly together with
    % the branch flowrates in the multi branch solver in case a flow P2P is
    % used. If the P2P flowrate does not depend on the branch flowrates use
    % a stationary P2P instead!
    
    % To easier discern between P2Ps that are stationary and do not change
    % within one tick and flow p2ps where the p2p flowrate must be
    % recalculated in every tick, a constant property is defined
    properties (Constant)
        % Boolean property to decide if this is a stationary or flow P2P
        bStationary = false;
    end
    
    
    methods
        function this = flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            %% flow p2p class constructor
            % checks if at least one of the phases to which the P2P is
            % connected is a flow and throws an error otherwise.
            %
            % Required Inputs:
            % oStore:   Store object in which the P2P is located
            % sName:    Name of the processor
            % sPhaseAndPortIn and sPhaseAndPortOut:
            %       Combination of Phase and Exme name in dot notation:
            %       phase.exme as a string. The in side is considered from
            %       the perspective of the P2P, which means in goes into
            %       the P2P but leaves the phase, which might be confusing
            %       at first. So for a positive flowrate the mass is taken
            %       from the in phase and exme!
            this@matter.procs.p2p(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);
            
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
    
    methods (Access = protected)
        function setMatterProperties(this, fFlowRate, arPartials)
            %% flow p2p setMatterProperties
            %
            % If the p2p is updated it sets the new flow rates using this
            % method. In addition to the basic operations from the general
            % P2P we must set register the phase massupdates to trigger a
            % recalculation of the partial mass composition
            %
            % Required Inputs:
            % fFlowRate:     The current total flowrate of the p2p in kg/s.
            %                Total means it must be the sum of all partial
            %                mass flow rates
            % arPartialMass: Vector containing the partial mass flow ratios
            %                to convert fFlowRate into a vector with
            %                partial mass flows by using fFlowRate *
            %                arPartialMass
            
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

