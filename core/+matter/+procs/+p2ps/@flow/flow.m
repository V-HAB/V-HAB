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
        function oSolver = findSolver(this)
            
            csExmes = fieldnames(this.oIn.oPhase.toProcsEXME);
            for iExme = 1:length(csExmes)
                if ~this.oIn.oPhase.toProcsEXME.(csExmes{iExme}).bFlowIsAProcP2P
                    if isa(this.oIn.oPhase.toProcsEXME.(csExmes{iExme}).oFlow.oBranch.oHandler, 'solver.matter_multibranch.iterative.branch')
                        oSolver = this.oIn.oPhase.coProcsEXME{iExme}.oFlow.oBranch.oHandler;
                    end
                end
            end
            
            csExmes = fieldnames(this.oOut.oPhase.toProcsEXME);
            for iExme = 1:length(csExmes)
                if ~this.oOut.oPhase.toProcsEXME.(csExmes{iExme}).bFlowIsAProcP2P
                    if isa(this.oOut.oPhase.toProcsEXME.(csExmes{iExme}).oFlow.oBranch.oHandler, 'solver.matter_multibranch.iterative.branch')
                        oSolver = this.oOut.oPhase.coProcsEXME{iExme}.oFlow.oBranch.oHandler;
                    end
                end
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

end

