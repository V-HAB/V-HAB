classdef stationary < matter.procs.p2p
    %P2P
    %
    %TODO
    %   - 
    
    
    properties (SetAccess = protected, GetAccess = protected)
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    
    
    methods
        function this = stationary(varargin)
            this@matter.procs.p2p(varargin{:});
            
        end
    end
    
    
    
    %% Internal helper methods
    methods (Access = protected)
        function [ mfMass, tiDir ] = getMasses(this)
            % Return matrix with masses of each species, first row is oIn,
            % second row is oOut phase. Returns a struct with fields 'in'
            % and 'out' containing 1 or 2 depending on the direction of the
            % flow rate, i.e. the actual 'inflow' phase.
            
            mfMass = [ this.oIn.oPhase.afMass; this.oOut.oPhase.afMass ];
            
            if this.fFlowRate >= 0, tiDir = struct('in', 1, 'out', 2);
            else                    tiDir = struct('in', 2, 'out', 1);
            end
        end
        
        
        
        function setMatterProperties(this, fFlowRate, arPartials)
            
            
            this.fLastUpdate = this.oStore.oTimer.fTime;
            
            
            
            setMatterProperties@matter.flow(this, fFlowRate, arPartials);
            
        end
    end
end

