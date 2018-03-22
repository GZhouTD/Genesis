clear 
close all
PE=[9.12716993443e+12;
9.01251754105e+12;
8.91543292888e+12;
8.3344285105e+12;
6.83391326672e+12;
7.27880698083e+12;
8.93561829007e+12;
9.27078551762e+12;
9.12716993443e+12;];
ape=mean(PE);
npe=PE/ape-1;
phi=(0:8)./8;
phip=(0:0.01:8)./8;
figure(1)
plot(phi,npe,'bx-')
hold on
plot(phip, ones(length(phip))*npe(1),'r-.')
hold off
enhance_plot
xlabel('shifted phase in unit of wavelength')
ylabel('normalized radiation pulse energy')
title('small phase shifter')

p1=load('o1.dat');
p2=load('o2.dat');
figure(2)
plot(p1(:,1),p1(:,2),'b-')
hold on
plot(p2(:,1),p2(:,2),'r-.')
hold off
enhance_plot
xlabel('S [\mum]')
ylabel('Power [W]')
title('large phase shifter')

