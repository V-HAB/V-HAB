classdef stationary < matter.procs.p2p
    %STATIONARY A P2P processor for a phase where the volumetric flow
    %through the phase is significantly smaller than its volume or even
    %zero.
    
    properties (SetAccess = protected, GetAccess = protected)
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        
    end
    
    
    
    methods
        function this = stationary(varargin)
            this@matter.procs.p2p(varargin{:});
            
            if this.oIn.oPhase.bFlow && this.oOut.oPhase.bFlow
                % P2Ps of this type are intended to be used in conjunction
                % with normal or boundary phases. If a flow phase is
                % connected to this use a flow p2p instead
                this.throw('p2p', 'The stationary P2P %s has a flow phase as either input or output. No side of the P2P can be a flow phase! For flow phases use flow P2Ps!', this.sName);
            end
            
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
            
            if this.fFlowRate >= 0
                tiDir = struct('in', 1, 'out', 2);
            else
                tiDir = struct('in', 2, 'out', 1);
            end
        end
        
        
        
        function setMatterProperties(this, fFlowRate, arPartials)
            if nargin < 3, arPartials = []; end
            
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

