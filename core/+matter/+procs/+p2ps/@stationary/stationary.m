classdef stationary < matter.procs.p2p
    %STATIONARY A P2P processor where the flowrate does not depend on the
    % mass flows passing through the connected phases, or where the phase
    % mass is much larger and the mass flows affecting it only have a minor
    % impact on it within one tick. The flowrate of the stationary P2P is
    % only calculated once and then is assumed to be constant for the rest
    % of the tick. The flow P2P would recalculate it iterativly within one
    % tick
    
    % to easier discern between P2Ps that are stationary and do not change
    % within one tick and flow p2ps where the p2p flowrate must be
    % recalculated in every tick, a constant property is defined
    properties (Constant)
        % Boolean property to decide if this is a stationary or flow P2P
        bStationary = true;
    end
    
    methods
        function this = stationary(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            %% stationary p2p class constructor
            % the stationary P2P does not check for flow or other phases,
            % as it can be used in either case!
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
            
        end
    end
end