

%Kennlinie meines Kompressors

%http://www.maximator.de/assets/mime/fab90f7a0d5202048ad8550de355ceff/MAXIMATOR%20Kompressoren%2011-2007.pdf

% x y aus datenblatt
x=[ 120 180  40 20]*10^5; %druck
y=0.001*1/60*[ - 400 0 300 600];%volumenstrom
p=polyfit(y,x,3);

v=-0.001:0.0001:0.002;
pressure_upper=v.^3*p(1)+v.^2*p(2)+v*p(3)+p(4);
plot(v,pressure_upper)
% hold on

% x=[2 1.6 0.4]*10^5; %druck
% y=0.001*1/60*[0 150 200];%volumenstrom
% p=polyfit(y,x,5);
%
% v=0:0.0001:0.0035;
% pressure_lower=v.^3*p(1)+v.^2*p(2)+v*p(3)+p(4);
% plot(v,pressure_lower)

u_low=1;
u_up=10;

%interpolte

%   plot(v,pressure)

for u=1:0.25:10
    
    pressure = pressure_lower + (u - u_low ) /(u_up - u_low)*(pressure_upper - pressure_lower);
    plot(v,pressure)
    hold on;
end



