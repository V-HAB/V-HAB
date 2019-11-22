classdef water_transport_toGaschanalO2 < matter.procs.p2ps.stationary
    % transports all the water from the liquid phase to the gasphase of the
    % chanal
    
    properties (SetAccess = public, GetAccess = public)
        
        arExtractPartials;
        fLastExec = 0;
        fMass_Stepold=100;
    end
    
    methods
        
        function this = water_transport_toGaschanalO2(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn,sPhaseOut);
            
            %define which substances should be transported
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.H2O) = 1;
        end
        
        function update(this)
            
            %calculate the timestep of the phase
            fTimeStep = this.oTimer.fTime - this.fLastExec;
            if fTimeStep <= 0
                return
            end
            
            %the flowrate is all the water divided by the actual time step
            %todo: check if Membrane and Diverses are the right object
            %names
            
            fMass_Stepnew=this.oIn.oPhase.afMass(this.oMT.tiN2I.H2O);
            
            fdeltaMass=fMass_Stepnew-this.fMass_Stepold;
            if fdeltaMass>0;
                fFlowRate =fdeltaMass/fTimeStep;
            else
                fFlowRate=0;
            end
            
            
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            this.fLastExec = this.oTimer.fTime;
            this.fMass_Stepold=this.oIn.oPhase.afMass(this.oMT.tiN2I.H2O);
        end
    end
end
