function ref = digitalizar_ficha
% Extract the red voltage, green current and blue capacity traces.
root = fileparts(mfilename('fullpath'));
data = fullfile(root,'datos');
img = double(imread(fullfile(data,'curva_ficha.png')));
assert(isequal(size(img),[828 1027 3]),'Unexpected image size.');
R=img(:,:,1); G=img(:,:,2); B=img(:,:,3);
x0=166.5;
xFit=polyfit([x0 285 403.5 519.5 638 756.5 875.5],0:30:180,1);
vFit=polyfit([712.5 621.5 530.5 441.5 351.5 260.5 169.5],2:.4:4.4,1);
cFit=polyfit([712.5 615 514.5 417.5 317 219.5],0:.2:1,1);
x=(167:778)';
% Restrict each extraction to its own, broadly traced corridor. This
% rejects colored antialiasing around neighboring text and curves.
vGuide=interp1([167 200 285 403 519 596 620 640 778], ...
    [369 343 326 304 265 225 214 214 214],x,'linear');
iGuide=interp1([167 596 623 646 671 703 745 778], ...
    [464 464 533 609 654 678 697 704],x,'linear');
qGuide=interp1([167 285 403 519 598 623 650 705 778], ...
    [711 587 465 347 259 233 221 208 203],x,'linear');
v=row_trace(R-max(G,B),x,vGuide,12);
i=row_trace(G-max(R,B),x,iGuide,19);
q=row_trace(B-max(R,G),x,qGuide,12);
time=(x-x0)*xFit(1)*60;
voltage=polyval(vFit,v);
current=2.2*polyval(cFit,i);
nominalCapacity=100*polyval(cFit,q);
% Map the chart's first and last capacity samples to 0 and 100 percent.
progress=100*(q(1)-q)/(q(1)-q(end));
assert(progress(1)==0 && progress(end)==100);
t=[0;time];
ref=table(t,t/60,[voltage(1);voltage],[current(1);current], ...
    [0;progress],[nominalCapacity(1);nominalCapacity], ...
    'VariableNames',{'Time_s','Time_min','Voltage_V','Current_A', ...
    'Relative_capacity_pct','Capacity_nominal_pct'});
writetable(ref,fullfile(data,'ficha_digitalizada.csv'));
end

function y = row_trace(contrast,x,guide,margin)
y=nan(size(x));
for k=1:numel(x)
    yy=(max(170,floor(guide(k)-margin)):min(714,ceil(guide(k)+margin)))';
    withColor=contrast(yy+1,x(k)+1)>65;
    if any(withColor), y(k)=median(yy(withColor)); end
end
has=isfinite(y);
assert(mean(has)>.98,'Missing samples in a published trace.');
y=interp1(x(has),y(has),x,'linear','extrap');
y=movmedian(y,3);
end
