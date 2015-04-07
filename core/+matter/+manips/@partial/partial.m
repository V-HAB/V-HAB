classdef partial < matter.manip
    %PARTIAl
    %
    %TODO
    %   - differences for solid, gas, liquid ...?
    %   - helpers for required energy, catalyst, produced energy, etc, then
    %     some energy object input for e.g. heat
    
    
    properties (SetAccess = private, GetAccess = public)
        % Changes in partial masses in kg/s
        afPartial;
    end
    
    methods
        function this = partial(sName, oPhase)
            this@matter.manip(sName, oPhase);
        end
        
        function update(this, afPartial, bAbsolute)
            % Set a afPartial FLOWRATE in kg/s. If bAbsolute is false
            % (default), afPartial is kg/s. If true, assumed to be kg and
            % converted to kg/s using last time step.
            
            if (nargin >= 3) && ~isempty(bAbsolute) && bAbsolute
                fTimeStep = this.getTimeStep();
                
                if fTimeStep == 0
                    afPartial = afPartial * 0;
                else
                    afPartial = afPartial / this.getTimeStep();
                end
            end
            
            this.afPartial = afPartial;
        end
    end
    
    methods (Access = protected)
        function afFlowRate = getTotalFlowRates(this)
            % Get all inwards and the stored partial masses as total kg/s
            % values.
            
            [ afFlowRates, mrInPartials ] = this.getInFlows();
            
            
            if ~isempty(afFlowRates)
                afFlowRate = sum(bsxfun(@times, afFlowRates, mrInPartials), 1);
            else
                afFlowRate = zeros(1, this.oPhase.oMT.iSubstances);
            end
        end
        
        
        function afMass = getTotalMasses(this)
            % Get all inwards and the stored partial masses as total kg/s
            % values.
            
            [ afMasses, mrInPartials ] = this.getMasses();
            
            
            if ~isempty(afMasses)
                afMass = sum(bsxfun(@times, afMasses, mrInPartials), 1);
            else
                afMass = zeros(1, this.oPhase.oMT.iSpecies);
            end
            
        end
    end
end

