/*  
 * TNModule.j
 *    
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>
@import <StropheCappuccino/StropheCappuccino.j>

TNExceptionModuleMethodNRequired = @"TNExceptionModuleMethodNRequired";

@implementation TNModule : CPView
{
    TNStropheRoster         roster              @accessors;
    TNStropheContact        contact             @accessors;
    CPNumber                moduleTabIndex      @accessors;
    CPString                moduleName          @accessors;
    CPString                moduleLabel         @accessors;
    CPArray                 moduleTypes         @accessors;
}

- (void)initializeWithContact:(TNStropheContact)aContact andRoster:(TNStropheRoster)aRoster
{
    [self setContact:aContact];
    [self setRoster:aRoster];
}

- (void)willLoad
{
    
}

- (void)willUnload
{

}

- (void)willShow
{
    
}

- (void)willHide
{
    
}
@end