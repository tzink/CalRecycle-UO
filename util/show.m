function show(D,fmt,filename,delim,tit,com)
% function show(D,fmt)
% displays a structure as if it were a database table.  fmt is a cell array of
% *printf format strings corresponding to the fields of D.  absent or empty
% defaults to '%_b'
%
% function show(D,fmt,filename)
% prints the output to filename instead of the screen. 
%
% function show(D,fmt,filename,delim) prints the output to filename instead of the
% screen using the supplied delimiter (default \t).  The special delimiter ',*' is
% designed to output a CSV file (skips width calculation)
%
% function show(D,fmt,filename,delim,title)
% Prints out the contents of cell array 'title' first- assume %s\n
%
% if filename isa cell array {'filename',0}, the second entry can be used to manage
% continual writes to a file:  
% 0 - default behavior
% 1 - header block (suppress totals and trailing newline); 
% 2 - data block (suppress column heading)
% 3 - data chunk (suppress column heading, totals and trailing newline);
% 
% The third entry {'filename',0,true} indicates whether to overwrite or append.  
% true - overwrite (remove existing file)
% false - append (default behavior)

dotitle=true;
forcetbl=false;
cont=0;
overwrite=false;

if nargin<6 com='#'; end

if nargin<5 
  dotitle=false; 
elseif islogical(tit)
  forcetbl=tit;
end
if nargin<4 || isempty(delim) delim='\t'; end
if strcmp( delim, ',*' )
  cont=1; % can still be overridden
end
if nargin<3 || isempty(filename) nofile=true; 
else 
  nofile=false; 
  if iscell(filename)
    if length(filename)>2
      overwrite=filename{3};
    end
    if length(filename)>1
      cont=filename{2};
    end
    filename=filename{1};
  end
end
if nargin<2 || isempty(fmt)   fmt={'%_b'}; end

if nofile
  NEWLINE='\n'; % command window
  filename='';
else
  NEWLINE='\r\n'; % DOS-compatible
end

if ~iscell(fmt) fmt={fmt}; end

if isempty(D)
  disp('Empty input.')
  return
end

if nofile fid=1; 
else
  if overwrite
    fid=fopen(filename,'w'); 
    appnd='overwrite';
  else
    fid=fopen(filename,'a'); 
    appnd='append';
  end
end
if dotitle & ~islogical(tit)
  fprintf(fid,NEWLINE);
  fprintf(fid,[com com com NEWLINE]);
  fprintf(fid,[com com  NEWLINE]);
  fprintf(fid,[com com ' %s' NEWLINE],tit{:});
  fprintf(fid,[com com NEWLINE]);
end

FN=fieldnames(D);

if any(cellfun(@isstruct,struct2cell(D)))
  % recurse into substructures; then show remainder
  fprintf(fid,'%s.',inputname(1));
  Drec=struct2cell(D);
  rec=cellfun(@isstruct,Drec);
  frec=find(rec);
  for i=1:length(frec)
    fprintf(fid,'%s:\n',FN{frec(i)});
    show(D.(FN{frec(i)}),fmt,filename,delim,false);
    D=rmfield(D,FN{frec(i)});
    fprintf(fid,'\n');
  end
  FN(frec)=[];
  fmt={'%_b'};
end

if length(D)==1 & ~forcetbl & cont==0
  shortprint(D(1),fmt,delim,fid);
  if ~nofile fclose(fid); end
  return
end

width=zeros(size(FN));

% first, establish field widths
accumfmt=repmat('d',1,length(FN));
for i=1:length(FN)
  myfmt=fmt{min([length(fmt),i])};
  if isempty(regexp(myfmt,'^%')) myfmt=['%' myfmt]; end
  % regex for fprintf format string is: '%0?[+-]?[0-9\.]*[bcdeEfgGiostuxX]{1,2}'
  fpf='^%([#0\ +-_]*)([0-9\.]*)([bcdeEfgGiostuxX]{1,2})';
  t_fmt=regexp(myfmt,fpf,'tokens'); % {1} - prefix {2} - width {3} char
  if isempty(t_fmt)
    disp([' ! Field ' FN{i} ': Invalid format string: ' myfmt])
    myfmt=ifinput('   Enter new format: ','%s','s');
    t_fmt=regexp(myfmt,fpf,'tokens'); % {1} - prefix {2} - width {3} char
  end
  if t_fmt{1}{1}=='_' % nothing supplied-- try our hand
    t_fmt{1}{1}='';
    k=1;
    while isempty(D(k).(FN{i})) & k<length(D) & k<1000
      k=k+1;
    end
    firstlook=D(k).(FN{i});
    if isnumeric(firstlook)
      secondlook=D(max([1 min(find([D.(FN{i})]>0))])).(FN{i});
      
      if fix(secondlook)==secondlook %&firstlook>0 
        t_fmt{1}{3}='d';
      else t_fmt{1}{3}='f';
      end
      accumfmt(i)='a';
    else
      t_fmt{1}{3}='s';
    end
  end % carry on
  %if ~nofile
  %  hdr_fmt{i}='%-s';
  %else
  if strcmp( delim, ',*' )
    width=0;
    hdr_fmt{i}='%s';
  elseif isempty(t_fmt{1}{2}) % no field width supplied - figure it out ourselves
    switch t_fmt{1}{3}(1)
      case {'b','d','i','o','t','u','x','X'} % integer
        maxsize=max([8,1+ceil(log10(max(abs([D(:).(FN{i})]))))]);
        width(i)=maxsize;
        t_fmt{1}{2}=num2str(maxsize);
        hdr_fmt{i}=['%-' num2str(maxsize) 's'];
        accumfmt(i)='a';
      case {'e','E','f','g','G'} % float
        t_fmt{1}{2}='12.4';
        width(i)=12;
        hdr_fmt{i}='%-12s';
        accumfmt(i)='a';
      otherwise % c, s - char
%         if strcmp(delim,',*') % special delimiter for CSV file: no padding
%           t_fmt{1}{2}='';
%           hdr_fmt{i}='%s';
%         else
          s_width=max(cellfun(@length,[{D.(FN{i})}])); % check out those parens
          t_fmt{1}{2}=[num2str(s_width) '.' num2str(s_width)]; 
          
          width(i)=s_width;
          hdr_fmt{i}=['%-' num2str(s_width) '.' num2str(s_width) 's'];
%        end
    end
  else
    hdr_fmt{i}=['%-' num2str(floor(str2num(t_fmt{1}{2}))) 's'];
    width(i)=floor(str2num(t_fmt{1}{2}));
  end
  if i==length(fmt) & i < length(FN)
    fmt{i+1}=fmt{i}; % continue last-supplied fmt
  end
  fmt{i}=['%' t_fmt{1}{:} ];
end

if length(fmt)>length(FN) fmt=fmt(1:length(FN)); end
delim( delim=='*' )='';
if nofile
  delim=repmat({' '},1,length(fmt));
else
  % tab-separated
  delim=repmat({delim},1,length(fmt));
end  
delim{end}='';
myfmt=[fmt;delim];
myhdr=[hdr_fmt;delim];

if bitand(cont,2)==0
  fprintf(fid,[myhdr{:} NEWLINE],FN{:});
end
if nofile
  total_width=sum(width)+length(FN)-1;
  fprintf(fid,'%s',repmat('=',1,total_width));
  fprintf(fid,NEWLINE);
end
for i=1:length(D)
  mydat=struct2cell(D(i));
  fprintf(fid,[myfmt{:} NEWLINE],mydat{:});
end
if length(D)>40 & bitand(cont,1)==0
  % print another header line at the bottom
  if nofile
    total_width=sum(width)+length(FN)-1;
    fprintf(fid,'%s',repmat('=',1,total_width));
  end
  fprintf(fid,NEWLINE);
  fprintf(fid,[myhdr{:} NEWLINE],FN{:});
end
if length(D)>1 & bitand(cont,1)==0
  % also add total row
  fprintf(fid,['%s' NEWLINE],'TOTAL');
  sumtotal=struct2cell(accum(D,accumfmt));
  sumtotal=sumtotal(1:end-1);
  [mydat{accumfmt=='d'}]=deal(' ');
  [mydat{accumfmt=='a'}]=deal(sumtotal{:});
  fprintf(fid,[myfmt{:} NEWLINE],mydat{:});
  fprintf(fid,NEWLINE);
end
if ~nofile 
  disp([' Written (' appnd ') to file ' filename])
  fclose(fid); 
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function shortprint(S,fmt,delim,fid)

if fid>1
  NEWLINE='\r\n'; % DOS-compatible
else
  NEWLINE='\n'; % cmd window
end

FN=fieldnames(S);

if strcmp( delim, ',*' )
  s_width=0;
else
  s_width=max(cellfun(@length,[FN(:)]));
end

for i=1:length(FN)
  myfmt=fmt{min([length(fmt),i])};
  if isempty(regexp(myfmt,'^%')) myfmt=['%' myfmt]; end
  % regex for fprintf format string is: '%0?[+-]?[0-9\.]*[bcdeEfgGiostuxX]{1,2}'
  fpf='^%([#0\ +-_]*)([0-9\.]*)([bcdeEfgGiostuxX]{1,2})';
  t_fmt=regexp(myfmt,fpf,'tokens'); % {1} - prefix {2} - width {3} char
  if isempty(t_fmt)
    disp([' ! Field ' FN{i} ': Invalid format string: ' myfmt])
    myfmt=ifinput('   Enter new format: ','%s','s');
    t_fmt=regexp(myfmt,fpf,'tokens'); % {1} - prefix {2} - width {3} char
  end
  if t_fmt{1}{1}=='_' % nothing supplied-- try our hand
    t_fmt{1}{1}='';
    if isnumeric(S.(FN{i}))
      if fix(S.(FN{i}))==S.(FN{i})  t_fmt{1}{3}='d';
      else t_fmt{1}{3}='f';
      end
    else
      t_fmt{1}{3}='s';
    end
  end % carry on
  if i==length(fmt) & i < length(FN)
    fmt{i+1}=fmt{i}; % continue last-supplied fmt
  end
  thisfmt=['%' t_fmt{1}{:} ];
  
  if strcmp( delim, ',*' )
    delim( delim=='*' )='';
    fprintf(fid,[delim '%-s '  delim thisfmt NEWLINE], FN{i},S.(FN{i}));
  else
    fprintf(fid,[delim '%*s ' delim thisfmt NEWLINE],s_width, FN{i},S.(FN{i}));
  end
end
fprintf(fid,NEWLINE);


