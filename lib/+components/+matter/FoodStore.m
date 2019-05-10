classdef FoodStore < matter.store
% Generic Store for food, includes the necessary exmes and functions to
% supply humans with food and receive food

    properties (SetAccess = protected, GetAccess = public)
        
        iHumans = 0;
        
        iInputs = 0;
        
        oParent;
    end
    
    methods
        function this = FoodStore(oParentSys, sName, fVolume, tfFood)
            % Creating a store based on the volume. Added 1 m³ to the
            % volume for the human interface phases
            this@matter.store(oParentSys, sName, fVolume + 1);
            
            matter.phases.mixture(this, 'Food', 'solid', tfFood, fVolume, this.oMT.Standard.Temperature, this.oMT.Standard.Pressure);
            
            this.oParent = oParentSys;
        end
        
        function requestFood = registerHuman(this, sPort)
            
            this.iHumans = this.iHumans + 1;
            
            oPhase = matter.phases.flow.mixture(this, ['Food_Output_', num2str(this.iHumans)], 'solid', [], 1e-4, this.oMT.Standard.Temperature, this.oMT.Standard.Pressure);
            
            matter.procs.exmes.mixture(this.toPhases.Food,     ['FoodPrepOut_', num2str(this.iHumans)]);
            matter.procs.exmes.mixture(oPhase,     ['FoodPrepIn_', num2str(this.iHumans)]);
            
            components.matter.P2Ps.ManualP2P(this.oParent, this, ['FoodPrepP2P_', num2str(this.iHumans)], ['Food.FoodPrepOut_', num2str(this.iHumans)], ['Food_Output_', num2str(this.iHumans), '.FoodPrepIn_', num2str(this.iHumans)]);
            
            matter.procs.exmes.mixture(oPhase,     ['Outlet_', num2str(this.iHumans)]);
            
            matter.branch(this.oParent, sPort, {}, [this.sName, '.Outlet_', num2str(this.iHumans)] , ['Food_Out_', num2str(this.iHumans)]);
            
            iHuman = this.iHumans;
            requestFood   = @(varargin) this.requestFood(iHuman, varargin{:});
        end
        
        function sInputExme = registerInput(this,~)
            this.iInputs = this.iInputs + 1;
            matter.procs.exmes.mixture(this.toPhases.Food,     ['FoodIn_', num2str(this.iInputs)]);
            
            sInputExme = ['FoodIn_', num2str(this.iInputs)];
        end
        
        function requestFood(this, iHuman, fEnergy, fTime, trComposition)
            oP2P = this.toProcsP2P.(['FoodPrepP2P_', num2str(iHuman)]);
            
            txResults = this.oMT.calculateNutritionalContent(this.toPhases.Food);
            
            if txResults.EdibleTotal.Mass == 0
                afPartialMasses = zeros(1, this.oMT.iSubstances);
                disp(['A Human is going hungry because there is nothing edible left in store ', this.sName])
            else
                % calculate mass transfer for the P2P
                if nargin > 4


                    keyboard()
                    trComposition;
                    afEnergy = fEnergy ;

                    afPartialMasses = 0;
                else
                    afPartialMasses = (this.toPhases.Food.arPartialMass * (txResults.EdibleTotal.Mass / txResults.EdibleTotal.TotalEnergy) * fEnergy);
                end
            end
            % Check if sufficient food of the demanded composition is
            % available
            oP2P.setMassTransfer(afPartialMasses, fTime);
        end
    end
    
    methods (Access = protected)
        
        function setVolume(this)
            % Overwriting the matter.store setVolume which would give both
            % gas phases the full volume.
        end
        
    end
end